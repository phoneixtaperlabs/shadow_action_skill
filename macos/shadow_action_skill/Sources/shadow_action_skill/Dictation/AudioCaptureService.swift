import AVFoundation
import OSLog

// MARK: - AudioCaptureError

enum AudioCaptureError: Error, LocalizedError {
    case microphonePermissionDenied
    case microphonePermissionRestricted
    case engineStartFailed(underlying: Error)
    case alreadyCapturing

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone access was denied. Please enable it in System Settings > Privacy & Security > Microphone."
        case .microphonePermissionRestricted:
            return "Microphone access is restricted on this device."
        case .engineStartFailed(let underlying):
            return "Audio engine failed to start: \(underlying.localizedDescription)"
        case .alreadyCapturing:
            return "Audio capture is already in progress. Call stop() before starting again."
        }
    }
}

// MARK: - AudioCaptureService

/// Captures microphone audio and delivers raw hardware-format PCM buffers.
///
/// No resampling or format conversion is performed — each ASR provider
/// is responsible for converting to its required format (e.g. 16kHz mono). (Coupling)
///
/// ## Usage
/// ```swift
/// let service = AudioCaptureService()
/// try await service.start()
///
/// for await buffer in service.bufferStream {
///     // Raw hardware-format PCM buffer
/// }
/// ```
actor AudioCaptureService {

    // MARK: - State

    /// Captures the full lifecycle: idle (no resources) or capturing (engine + streams active).
    /// Single source of truth — eliminates impossible states. (Predictability)
    private enum State {
        case idle
        case capturing(
            continuation: AsyncStream<AVAudioPCMBuffer>.Continuation,
            rmsContinuation: AsyncStream<Float>.Continuation
        )
    }

    private var state: State = .idle

    var isCapturing: Bool {
        if case .capturing = state { return true }
        return false
    }

    /// Stream of raw hardware-format PCM buffers. A new stream is created each time `start()` is called.
    private(set) var bufferStream = AsyncStream<AVAudioPCMBuffer> { $0.finish() }

    /// Stream of RMS volume levels (0.0–1.0) computed from each tap callback.
    /// Used by `DictationIndicatorView` to drive the dots ↔ waveform morph.
    private(set) var rmsStream = AsyncStream<Float> { $0.finish() }

    // MARK: - Private Properties

    private let audioEngine = AVAudioEngine()
    private let logger = Logger(subsystem: "shadow_action_skill", category: "AudioCapture")

    private static let tapBufferSize: AVAudioFrameCount = 4096

    // MARK: - Lifecycle

    /// Begins audio capture. Throws if already capturing — call `stop()` first.
    func start() async throws(AudioCaptureError) {
        guard !isCapturing else { throw .alreadyCapturing }

        try await requestMicrophonePermission()

        let (stream, continuation) = AsyncStream<AVAudioPCMBuffer>.makeStream()
        let (rmsStreamNew, rmsContinuation) = AsyncStream<Float>.makeStream()

        continuation.onTermination = { @Sendable [weak self] _ in
            guard let self else { return }
            Task { await self.stop() }
        }

        do {
            try installTapAndStartEngine(
                continuation: continuation,
                rmsContinuation: rmsContinuation
            )
        } catch {
            tearDownEngine()
            continuation.finish()
            rmsContinuation.finish()
            throw .engineStartFailed(underlying: error)
        }

        // Commit state only after engine is running successfully
        self.bufferStream = stream
        self.rmsStream = rmsStreamNew
        self.state = .capturing(
            continuation: continuation,
            rmsContinuation: rmsContinuation
        )
    }

    /// Stops audio capture and finishes the buffer stream.
    func stop() {
        guard case .capturing(let continuation, let rmsContinuation) = state else { return }

        tearDownEngine()
        continuation.finish()
        rmsContinuation.finish()

        state = .idle
        logger.info("[AudioCapture] Stopped")
    }

    // MARK: - Private

    private func requestMicrophonePermission() async throws(AudioCaptureError) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            if !granted { throw .microphonePermissionDenied }
        case .denied:
            throw .microphonePermissionDenied
        case .restricted:
            throw .microphonePermissionRestricted
        @unknown default:
            throw .microphonePermissionDenied
        }
    }

    /// Removes tap, stops engine, resets graph. Safe to call in any state.
    private func tearDownEngine() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        audioEngine.reset()
    }

    /// Taps `inputNode` at hardware format, yields raw buffers and RMS levels.
    ///
    /// Each tap callback copies into a fresh owned buffer before yielding,
    /// since the tap buffer is only valid for the duration of the callback.
    /// RMS is computed inline — lightweight, no extra threads.
    private func installTapAndStartEngine(
        continuation: AsyncStream<AVAudioPCMBuffer>.Continuation,
        rmsContinuation: AsyncStream<Float>.Continuation
    ) throws {
        audioEngine.reset()

        let inputNode = audioEngine.inputNode
        let hardwareFormat = inputNode.outputFormat(forBus: 0)

        logger.info("[AudioCapture] Hardware: \(hardwareFormat.sampleRate)Hz, \(hardwareFormat.channelCount)ch")

        inputNode.installTap(
            onBus: 0,
            bufferSize: Self.tapBufferSize,
            format: hardwareFormat
        ) { buffer, _ in
            let frameLength = Int(buffer.frameLength)
            guard frameLength > 0 else { return }

            // Compute RMS BEFORE yielding the buffer. The buffer is a reference type
            // reused by the audio system — once yielded, downstream consumers may
            // invalidate the data, causing floatChannelData to read all zeros.
            if let channelData = buffer.floatChannelData?[0] {
                var sum: Float = 0
                for i in 0..<frameLength {
                    let sample = channelData[i]
                    sum += sample * sample
                }
                let rawRMS = sqrtf(sum / Float(frameLength))

                // Convert to dB, then normalize: -60 dB → 0.0, 0 dB → 1.0
                let db = 20 * log10f(max(rawRMS, 1e-6))
                let floorDB: Float = -60
                let normalized = max(0, min(1, (db - floorDB) / -floorDB))
                rmsContinuation.yield(normalized)
            }

            continuation.yield(buffer)
        }

        try audioEngine.start()
        logger.info("[AudioCapture] Engine started")
    }
}
