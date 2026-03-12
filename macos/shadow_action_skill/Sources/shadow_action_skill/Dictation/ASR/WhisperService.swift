import AVFoundation
import FluidAudio
import OSLog
import whisper

// MARK: - WhisperService

/// ASR provider backed by whisper.cpp (v1.7.5 XCFramework).
///
/// Supports two processing strategies (configured via `WhisperServiceConfig.strategy`):
/// - **fixedBatch**: Fixed-size chunks decoded independently. Lower latency, less context.
/// - **growingAccumulator**: Re-runs inference on all accumulated audio each step.
///   Better quality (more context → fewer hallucinations), capped at 30s.
///
/// All whisper.cpp C API usage is contained within this file —
/// no whisper types leak beyond the `ASRService` protocol boundary. (Coupling)
actor WhisperService: ASRService {

    // MARK: - ASRService Properties

    nonisolated let providerName = "Whisper"

    var isReady: Bool {
        switch state {
        case .ready, .streaming: return true
        default: return false
        }
    }

    // MARK: - State

    /// Explicit state machine matching AudioCaptureService's pattern. (Predictability)
    private enum State {
        case idle
        case loading
        case ready(context: OpaquePointer)
        case streaming(
            context: OpaquePointer,
            task: Task<Void, Never>,
            continuation: AsyncStream<TranscriptionResult>.Continuation
        )
    }

    private var state: State = .idle

    private let config: WhisperServiceConfig
    private let logger = Logger(subsystem: "shadow_action_skill", category: "WhisperASR")

    // MARK: - Init

    init(config: WhisperServiceConfig = .default) {
        self.config = config
    }

    // MARK: - ASRService Protocol

    func prepare() async throws {
        guard case .idle = state else { return } // Idempotent
        state = .loading

        let modelPath = config.resolvedModelPath

        guard FileManager.default.fileExists(atPath: modelPath) else {
            state = .idle
            throw ASRServiceError.modelUnavailable(
                reason: "Whisper model file not found at: \(modelPath)"
            )
        }

        var contextParams = whisper_context_default_params()
        contextParams.use_gpu = true

        guard let ctx = whisper_init_from_file_with_params(modelPath, contextParams) else {
            state = .idle
            throw ASRServiceError.modelLoadFailed(
                reason: "whisper_init_from_file_with_params returned nil for: \(modelPath)"
            )
        }

        state = .ready(context: ctx)
        logger.info("[WhisperASR] Model loaded successfully from \(modelPath)")
    }

    func startStreaming(
        audioBuffers: AsyncStream<AVAudioPCMBuffer>
    ) async throws -> AsyncStream<TranscriptionResult> {
        guard case .ready(let ctx) = state else {
            throw ASRServiceError.notReady
        }

        let (stream, continuation) = AsyncStream<TranscriptionResult>.makeStream()

        let task = Task { [config, logger] in
            await Self.processAudioStream(
                audioBuffers,
                context: ctx,
                config: config,
                continuation: continuation,
                logger: logger
            )
            continuation.finish()
        }

        state = .streaming(context: ctx, task: task, continuation: continuation)
        return stream
    }

    func stopStreaming() async {
        guard case .streaming(let ctx, let task, _) = state else { return }
        task.cancel()
        // Don't finish continuation here — the task closure (line 101) does it
        // after processAudioStream returns, which includes flushRemaining yielding isFinal:true.
        await task.value
        state = .ready(context: ctx)
        logger.info("[WhisperASR] Streaming stopped")
    }

    func teardown() async {
        await stopStreaming()
        if case .ready(let ctx) = state {
            whisper_free(ctx)
        }
        state = .idle
        logger.info("[WhisperASR] Teardown complete")
    }

    // MARK: - Audio Processing

    /// Dispatches to the configured processing strategy.
    ///
    /// Static method to avoid capturing `self` in the streaming task. (Memory)
    private static func processAudioStream(
        _ buffers: AsyncStream<AVAudioPCMBuffer>,
        context: OpaquePointer,
        config: WhisperServiceConfig,
        continuation: AsyncStream<TranscriptionResult>.Continuation,
        logger: Logger
    ) async {
        switch config.strategy {
        case .fixedBatch:
            await processFixedBatch(buffers, context: context, config: config, continuation: continuation, logger: logger)
        case .growingAccumulator:
            await processGrowingAccumulator(buffers, context: context, config: config, continuation: continuation, logger: logger)
        }
    }

    // MARK: Fixed Batch Strategy

    /// Decodes fixed-size chunks independently. Each batch is discarded after inference.
    private static func processFixedBatch(
        _ buffers: AsyncStream<AVAudioPCMBuffer>,
        context: OpaquePointer,
        config: WhisperServiceConfig,
        continuation: AsyncStream<TranscriptionResult>.Continuation,
        logger: Logger
    ) async {
        var sampleAccumulator: [Float] = []
        let audioConverter = AudioConverter()

        for await buffer in buffers {
            guard !Task.isCancelled else { break }

            let samples: [Float]
            do {
                samples = try audioConverter.resampleBuffer(buffer)
            } catch {
                logger.error("[WhisperASR] Audio conversion failed: \(error)")
                continue
            }

            guard !samples.isEmpty else { continue }
            sampleAccumulator.append(contentsOf: samples)

            while sampleAccumulator.count >= config.batchSizeSamples {
                guard !Task.isCancelled else { return }

                let batch = Array(sampleAccumulator.prefix(config.batchSizeSamples))
                sampleAccumulator.removeFirst(config.batchSizeSamples)

                logger.info("[WhisperASR] Processing batch: \(batch.count) samples (\(Double(batch.count) / WhisperServiceConfig.sampleRate, format: .fixed(precision: 1))s)")

                if let result = runInference(
                    on: batch, context: context, config: config, isFinal: false, logger: logger
                ) {
                    logger.info("[WhisperASR] Batch result: \"\(result.text)\"")
                    continuation.yield(result)
                } else {
                    logger.debug("[WhisperASR] Batch produced no text")
                }
            }
        }

        flushRemaining(&sampleAccumulator, committedText: "", context: context, config: config, continuation: continuation, logger: logger)
    }

    // MARK: Growing Accumulator Strategy

    /// Accumulates all audio and re-runs inference on the entire buffer every `stepSizeSamples`.
    /// Whisper gets more context each time → dramatically fewer hallucinations.
    /// Capped at `maxAccumulatorSamples` (30s) to bound memory.
    private static func processGrowingAccumulator(
        _ buffers: AsyncStream<AVAudioPCMBuffer>,
        context: OpaquePointer,
        config: WhisperServiceConfig,
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
                logger.error("[WhisperASR] Audio conversion failed: \(error)")
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
                logger.info("[WhisperASR] Committed text at trim boundary: \"\(committedText)\"")
            }

            // Run inference every stepSizeSamples of new audio
            let newSamples = sampleAccumulator.count - samplesAtLastInference
            guard newSamples >= config.stepSizeSamples,
                  sampleAccumulator.count >= config.minSamplesForInference else { continue }
            guard !Task.isCancelled else { break }

            logger.info("[WhisperASR] Processing accumulator: \(sampleAccumulator.count) samples (\(Double(sampleAccumulator.count) / WhisperServiceConfig.sampleRate, format: .fixed(precision: 1))s)")

            if let result = runInference(
                on: sampleAccumulator, context: context, config: config, isFinal: false, logger: logger
            ) {
                lastInferenceText = result.text

                let fullText = committedText.isEmpty
                    ? result.text
                    : committedText + " " + result.text

                logger.info("[WhisperASR] Accumulator result: \"\(fullText)\"")
                continuation.yield(TranscriptionResult(
                    text: fullText,
                    isFinal: false,
                    confidence: result.confidence,
                    segments: result.segments
                ))
            } else {
                logger.debug("[WhisperASR] Accumulator produced no text")
            }

            samplesAtLastInference = sampleAccumulator.count
        }

        // Final inference on all accumulated audio — prepend committed text
        flushRemaining(
            &sampleAccumulator,
            committedText: committedText,
            context: context,
            config: config,
            continuation: continuation,
            logger: logger
        )
    }

    // MARK: Flush

    /// Runs final inference on remaining audio (pads to 1s minimum if needed).
    /// Prepends `committedText` from previous accumulator windows.
    private static func flushRemaining(
        _ sampleAccumulator: inout [Float],
        committedText: String,
        context: OpaquePointer,
        config: WhisperServiceConfig,
        continuation: AsyncStream<TranscriptionResult>.Continuation,
        logger: Logger
    ) {
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
        logger.info("[WhisperASR] Final flush: \(count) samples (\(Double(count) / WhisperServiceConfig.sampleRate, format: .fixed(precision: 1))s)")

        if let finalResult = runInference(
            on: sampleAccumulator, context: context, config: config, isFinal: true, logger: logger
        ) {
            let fullText = committedText.isEmpty
                ? finalResult.text
                : committedText + " " + finalResult.text

            logger.info("[WhisperASR] Final result: \"\(fullText)\"")
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

    /// Run whisper.cpp inference on a chunk of Float32 audio samples.
    private static func runInference(
        on samples: [Float],
        context: OpaquePointer,
        config: WhisperServiceConfig,
        isFinal: Bool,
        logger: Logger
    ) -> TranscriptionResult? {
        // Use withCString to guarantee the language pointer lives through whisper_full.
        let language = config.language ?? "auto"
        return language.withCString { langPtr in
            var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
            params.n_threads = Int32(config.threadCount)
            params.no_context = true
            params.no_timestamps = true
            params.token_timestamps = false
            params.print_special = false
            params.print_progress = false
            params.print_realtime = false
            params.print_timestamps = false
            params.suppress_nst = true
            params.language = langPtr

            let result = samples.withUnsafeBufferPointer { bufferPtr in
                whisper_full(context, params, bufferPtr.baseAddress!, Int32(samples.count))
            }

            guard result == 0 else {
                logger.error("[WhisperASR] whisper_full failed with code \(result)")
                return nil
            }

            let segmentCount = whisper_full_n_segments(context)
            var text = ""
            var segments: [TranscriptionSegment] = []

            for i in 0..<segmentCount {
                guard let cStr = whisper_full_get_segment_text(context, Int32(i)) else { continue }
                let segmentText = String(cString: cStr)
                text += segmentText

                // Timestamps are in centiseconds (1/100th of a second)
                let t0 = TimeInterval(whisper_full_get_segment_t0(context, Int32(i))) / 100.0
                let t1 = TimeInterval(whisper_full_get_segment_t1(context, Int32(i))) / 100.0

                segments.append(TranscriptionSegment(
                    text: segmentText,
                    startTime: t0,
                    endTime: t1,
                    confidence: 1.0
                ))
            }

            let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedText.isEmpty else { return nil }

            return TranscriptionResult(
                text: trimmedText,
                isFinal: isFinal,
                confidence: 1.0,
                segments: segments
            )
        }
    }
}

// MARK: - Processing Strategy

enum WhisperProcessingStrategy: Sendable {
    /// Fixed-size chunks decoded independently and discarded.
    case fixedBatch
    /// Growing accumulator — re-runs inference on all audio each step for better context.
    case growingAccumulator
}

// MARK: - WhisperServiceConfig

/// Configuration for WhisperService. Provider-internal — never exposed through the protocol. (Coupling)
struct WhisperServiceConfig: Sendable {

    /// Sample rate whisper.cpp expects (Hz).
    static let sampleRate: Double = 16_000.0

    /// Model filename (e.g., "ggml-small-q5_1.bin").
    var modelName: String

    /// Number of threads for inference.
    let threadCount: Int

    /// Language code (nil = auto-detect).
    var language: String?

    /// Processing strategy.
    let strategy: WhisperProcessingStrategy

    /// Fixed batch size in samples (used by `.fixedBatch`).
    let batchSizeSamples: Int

    /// How many new samples to accumulate before re-running inference (used by `.growingAccumulator`).
    let stepSizeSamples: Int

    /// Maximum accumulator size in samples to cap memory (used by `.growingAccumulator`).
    let maxAccumulatorSamples: Int

    /// Minimum samples before whisper will accept input (whisper.cpp requires >= 1000ms).
    let minSamplesForInference: Int

    /// Resolved model path under Application Support.
    var resolvedModelPath: String {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!

        return appSupport
            .appendingPathComponent("com.taperlabs.shadow")
            .appendingPathComponent("shared")
            .appendingPathComponent(modelName)
            .path
    }

    static let `default` = WhisperServiceConfig(
        modelName: "ggml-small-q5_1.bin",
        threadCount: 4,
        language: nil,
        strategy: .growingAccumulator,
        batchSizeSamples: Int(sampleRate) * 2,        // 2s (fixedBatch)
        stepSizeSamples: Int(sampleRate) * 2,          // run inference every 2s of new audio (growingAccumulator)
        maxAccumulatorSamples: Int(sampleRate) * 10,   // cap at 10s (growingAccumulator)
        minSamplesForInference: Int(sampleRate) * 1    // whisper minimum: 1 second
    )
}
