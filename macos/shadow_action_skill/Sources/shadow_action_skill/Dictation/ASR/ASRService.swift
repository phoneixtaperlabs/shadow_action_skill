import AVFoundation

// MARK: - ASRService

/// Contract for any automatic speech recognition provider.
///
/// Conforming types are expected to be actors internally for thread safety,
/// matching `AudioCaptureService`'s concurrency pattern.
///
/// The protocol defines a clear lifecycle:
/// `prepare → startStreaming → stopStreaming → teardown`
///
/// ## Usage
/// ```swift
/// let service: any ASRService = WhisperService()
/// try await service.prepare()
///
/// let stream = try await service.startStreaming(
///     audioBuffers: audioCaptureService.bufferStream
/// )
/// for await result in stream {
///     print(result.text, result.isFinal)
/// }
/// ```
protocol ASRService: AnyObject, Sendable {

    /// Human-readable provider name for logging and diagnostics.
    var providerName: String { get }

    /// Whether the service has loaded its models and is ready to transcribe.
    var isReady: Bool { get async }

    /// Load models and prepare for transcription.
    /// Call this before `startStreaming`. Idempotent if already prepared.
    func prepare() async throws

    /// Begin streaming transcription from an audio buffer stream.
    ///
    /// Consumes `AVAudioPCMBuffer` values from the provided stream and emits
    /// `TranscriptionResult` values as speech is recognized.
    ///
    /// - Parameter audioBuffers: 16kHz mono Float32 PCM buffers from `AudioCaptureService`.
    /// - Returns: An `AsyncStream` of transcription results (partial and final).
    func startStreaming(
        audioBuffers: AsyncStream<AVAudioPCMBuffer>
    ) async throws -> AsyncStream<TranscriptionResult>

    /// Stop an active streaming session.
    /// Safe to call when not streaming (no-op).
    func stopStreaming() async

    /// Release all loaded models and free memory.
    func teardown() async
}
