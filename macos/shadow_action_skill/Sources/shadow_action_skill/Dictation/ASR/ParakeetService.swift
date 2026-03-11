import AVFoundation
import FluidAudio
import OSLog

// MARK: - ParakeetService

/// ASR provider backed by FluidAudio's Parakeet TDT model (CoreML).
///
/// Uses the growing accumulator strategy: re-runs batch inference on all
/// accumulated audio every `stepSizeSamples`, capped at `maxAccumulatorSamples`.
/// Each `AsrManager.transcribe` call is stateless (decoder resets internally).
///
/// All FluidAudio types are contained within this file —
/// no FluidAudio types leak beyond the `ASRService` protocol boundary. (Coupling)
actor ParakeetService: ASRService {

    // MARK: - ASRService Properties

    nonisolated let providerName = "ParakeetService"

    var isReady: Bool {
        switch state {
        case .ready, .streaming: return true
        default: return false
        }
    }

    // MARK: - State

    /// Explicit state machine matching WhisperService's pattern. (Predictability)
    private enum State {
        case idle
        case loading
        case ready(manager: AsrManager)
        case streaming(
            manager: AsrManager,
            task: Task<Void, Never>,
            continuation: AsyncStream<TranscriptionResult>.Continuation
        )
    }

    private var state: State = .idle

    private let config: ParakeetServiceConfig
    private let logger = Logger(subsystem: "shadow_action_skill", category: "ParakeetASR")

    // MARK: - Init

    init(config: ParakeetServiceConfig = .default) {
        self.config = config
    }

    // MARK: - ASRService Protocol

    func prepare() async throws {
        guard case .idle = state else { return } // Idempotent
        state = .loading

        let modelDirectory = config.resolvedModelDirectory

        guard FileManager.default.fileExists(atPath: modelDirectory.path) else {
            state = .idle
            throw ASRServiceError.modelUnavailable(
                reason: "Parakeet model directory not found at: \(modelDirectory.path)"
            )
        }

        do {
            let models = try await AsrModels.load(
                from: modelDirectory,
                version: config.modelVersion
            )

            let manager = AsrManager(config: .default)
            try await manager.initialize(models: models)

            state = .ready(manager: manager)
            let versionLabel = config.modelVersion == .v2 ? "v2" : "v3"
            logger.info("[ParakeetASR] Model loaded successfully (Parakeet \(versionLabel))")
        } catch {
            state = .idle
            throw ASRServiceError.modelLoadFailed(
                reason: "FluidAudio model load failed: \(error.localizedDescription)"
            )
        }
    }

    func startStreaming(
        audioBuffers: AsyncStream<AVAudioPCMBuffer>
    ) async throws -> AsyncStream<TranscriptionResult> {
        guard case .ready(let manager) = state else {
            throw ASRServiceError.notReady
        }

        let (stream, continuation) = AsyncStream<TranscriptionResult>.makeStream()
        let task = spawnProcessingTask(
            buffers: audioBuffers,
            manager: manager,
            continuation: continuation
        )

        state = .streaming(manager: manager, task: task, continuation: continuation)
        return stream
    }

    func stopStreaming() async {
        guard case .streaming(let manager, let task, _) = state else { return }
        // Don't cancel — the audio stream finishing naturally exits the loop,
        // then flushRemainingAsync runs final inference. Cancelling would
        // poison the flush's `await manager.transcribe()` with CancellationError.
        await task.value
        state = .ready(manager: manager)
        logger.info("[ParakeetASR] Streaming stopped")
    }

    func teardown() async {
        await stopStreaming()
        if case .ready(let manager) = state {
            manager.cleanup()
        }
        state = .idle
        logger.info("[ParakeetASR] Teardown complete")
    }

    // MARK: - Task Spawning

    /// Spawns the audio processing task, inheriting actor isolation via SE-0420
    /// so the non-Sendable `AsrManager` can be safely captured. (Concurrency)
    private func spawnProcessingTask(
        buffers: AsyncStream<AVAudioPCMBuffer>,
        manager: AsrManager,
        continuation: AsyncStream<TranscriptionResult>.Continuation,
        isolation: isolated (any Actor)? = #isolation
    ) -> Task<Void, Never> {
        Task { [config, logger] in
            _ = isolation // Forces Task to inherit actor isolation (SE-0420)
            await Self.processGrowingAccumulator(
                buffers,
                manager: manager,
                config: config,
                continuation: continuation,
                logger: logger
            )
            continuation.finish()
        }
    }

    // MARK: - Audio Processing (static — no self capture)

    /// Accumulates all audio and re-runs inference on the entire buffer every `stepSizeSamples`.
    /// Parakeet gets the full context each time. Capped at `maxAccumulatorSamples` to bound memory.
    private static func processGrowingAccumulator(
        _ buffers: AsyncStream<AVAudioPCMBuffer>,
        manager: AsrManager,
        config: ParakeetServiceConfig,
        continuation: AsyncStream<TranscriptionResult>.Continuation,
        logger: Logger
    ) async {
        var sampleAccumulator: [Float] = []
        var samplesAtLastInference = 0
        var committedText = ""
        var lastInferenceText = ""
        let audioConverter = AudioConverter()

        for await buffer in buffers {
            guard !Task.isCancelled else { break }

            let samples: [Float]
            do {
                samples = try audioConverter.resampleBuffer(buffer)
            } catch {
                logger.error("[ParakeetASR] Audio conversion failed: \(error)")
                continue
            }

            guard !samples.isEmpty else { continue }
            sampleAccumulator.append(contentsOf: samples)

            // Cap at maxAccumulatorSamples — commit current text, reset audio for fresh window
            if sampleAccumulator.count > config.maxAccumulatorSamples {
                committedText += lastInferenceText
                lastInferenceText = ""
                let keepSamples = config.minSamplesForInference // 1s overlap for continuity
                sampleAccumulator = Array(sampleAccumulator.suffix(keepSamples))
                samplesAtLastInference = 0
                logger.info("[ParakeetASR] Committed text at trim boundary: \"\(committedText)\"")
            }

            // Run inference every stepSizeSamples of new audio
            let newSamples = sampleAccumulator.count - samplesAtLastInference
            guard newSamples >= config.stepSizeSamples,
                  sampleAccumulator.count >= config.minSamplesForInference else { continue }
            guard !Task.isCancelled else { break }

            logger.info("[ParakeetASR] Processing accumulator: \(sampleAccumulator.count) samples (\(Double(sampleAccumulator.count) / ParakeetServiceConfig.sampleRate, format: .fixed(precision: 1))s)")

            if let result = await runInference(
                on: sampleAccumulator, manager: manager, isFinal: false, logger: logger
            ) {
                lastInferenceText = result.text

                let fullText = committedText.isEmpty
                    ? result.text
                    : committedText + " " + result.text

                logger.info("[ParakeetASR] Accumulator result: \"\(fullText)\"")
                continuation.yield(TranscriptionResult(
                    text: fullText,
                    isFinal: false,
                    confidence: result.confidence,
                    segments: result.segments
                ))
            } else {
                logger.debug("[ParakeetASR] Accumulator produced no text")
            }

            samplesAtLastInference = sampleAccumulator.count
        }

        // Commit the last inference text before flushing — otherwise it's lost
        // when the loop exits between a trim boundary and the flush.
        if !lastInferenceText.isEmpty {
            committedText += committedText.isEmpty ? lastInferenceText : " " + lastInferenceText
        }

        // Final inference on all accumulated audio — prepend committed text
        await flushRemainingAsync(
            &sampleAccumulator,
            committedText: committedText,
            manager: manager,
            config: config,
            continuation: continuation,
            logger: logger
        )
    }

    // MARK: - Flush (async — AsrManager.transcribe is async)

    /// Runs final inference on remaining audio (pads to 1s minimum if needed).
    /// Prepends `committedText` from previous accumulator windows.
    private static func flushRemainingAsync(
        _ sampleAccumulator: inout [Float],
        committedText: String,
        manager: AsrManager,
        config: ParakeetServiceConfig,
        continuation: AsyncStream<TranscriptionResult>.Continuation,
        logger: Logger
    ) async {
        guard !sampleAccumulator.isEmpty else {
            // No remaining audio but we may have committed text to yield
            if !committedText.isEmpty {
                continuation.yield(TranscriptionResult(
                    text: committedText,
                    isFinal: true,
                    confidence: 1.0,
                    segments: []
                ))
            }
            return
        }

        if sampleAccumulator.count < config.minSamplesForInference {
            let padding = config.minSamplesForInference - sampleAccumulator.count
            sampleAccumulator.append(contentsOf: [Float](repeating: 0.0, count: padding))
        }

        let count = sampleAccumulator.count
        logger.info("[ParakeetASR] Final flush: \(count) samples (\(Double(count) / ParakeetServiceConfig.sampleRate, format: .fixed(precision: 1))s)")

        if let finalResult = await runInference(
            on: sampleAccumulator, manager: manager, isFinal: true, logger: logger
        ) {
            let fullText = committedText.isEmpty
                ? finalResult.text
                : committedText + " " + finalResult.text

            logger.info("[ParakeetASR] Final result: \"\(fullText)\"")
            continuation.yield(TranscriptionResult(
                text: fullText,
                isFinal: true,
                confidence: finalResult.confidence,
                segments: finalResult.segments
            ))
        } else if !committedText.isEmpty {
            // Inference produced nothing but we have committed text
            continuation.yield(TranscriptionResult(
                text: committedText,
                isFinal: true,
                confidence: 1.0,
                segments: []
            ))
        }
    }

    /// Run FluidAudio batch inference on accumulated Float32 audio samples.
    private static func runInference(
        on samples: [Float],
        manager: AsrManager,
        isFinal: Bool,
        logger: Logger
    ) async -> TranscriptionResult? {
        do {
            let result = try await manager.transcribe(samples, source: .microphone)
            let trimmedText = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedText.isEmpty else { return nil }

            return TranscriptionResult(
                text: trimmedText,
                isFinal: isFinal,
                confidence: result.confidence,
                segments: []
            )
        } catch {
            logger.error("[ParakeetASR] transcribe failed: \(error)")
            return nil
        }
    }
}

// MARK: - ParakeetServiceConfig

/// Configuration for ParakeetService. Provider-internal — never exposed through the protocol. (Coupling)
struct ParakeetServiceConfig: Sendable {

    /// Sample rate Parakeet expects (Hz).
    static let sampleRate: Double = 16_000.0

    /// Parakeet model version (.v2 = English-only, .v3 = multilingual).
    let modelVersion: AsrModelVersion

    /// How many new samples to accumulate before re-running inference.
    let stepSizeSamples: Int

    /// Maximum accumulator size in samples to cap memory (must stay under 240,000 / 15s CoreML limit).
    let maxAccumulatorSamples: Int

    /// Minimum samples before AsrManager will accept input (requires >= 1s / 16,000 samples).
    let minSamplesForInference: Int

    /// Resolved model directory under Application Support.
    /// Points to the repo folder; `AsrModels.load(from:)` derives the parent internally.
    var resolvedModelDirectory: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!

        return appSupport
            .appendingPathComponent("com.taperlabs.shadow")
            .appendingPathComponent("shared")
            .appendingPathComponent("parakeet-tdt-0.6b-v2-coreml")
    }

    static let `default` = ParakeetServiceConfig(
        modelVersion: .v2,
        stepSizeSamples: Int(sampleRate) * 2,          // 2s — run inference every 2s of new audio
        maxAccumulatorSamples: Int(sampleRate) * 10,    // 10s — well under 15s CoreML limit
        minSamplesForInference: Int(sampleRate) * 1     // 1s — AsrManager minimum
    )
}
