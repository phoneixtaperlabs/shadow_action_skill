import Foundation

// MARK: - ASRServiceError

/// Errors that any ASR provider may throw through the `ASRService` protocol.
///
/// Matches the existing `AudioCaptureError` pattern: exhaustive enum
/// with associated values and `LocalizedError` conformance.
/// Consumers handle the same error cases regardless of provider. (Predictability)
enum ASRServiceError: Error, LocalizedError {

    /// Models failed to download or are missing.
    case modelUnavailable(reason: String)

    /// Models failed to load into memory or compile.
    case modelLoadFailed(reason: String)

    /// The service is not in the correct state for the requested operation.
    case notReady

    /// Audio data was invalid or in an unexpected format.
    case invalidAudioFormat(reason: String)

    /// Transcription processing failed.
    case transcriptionFailed(reason: String)

    /// A provider-specific error that doesn't map to the above cases.
    case providerError(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .modelUnavailable(let reason):
            return "ASR model unavailable: \(reason)"
        case .modelLoadFailed(let reason):
            return "ASR model load failed: \(reason)"
        case .notReady:
            return "ASR service is not ready. Call prepare() first."
        case .invalidAudioFormat(let reason):
            return "Invalid audio format: \(reason)"
        case .transcriptionFailed(let reason):
            return "Transcription failed: \(reason)"
        case .providerError(let underlying):
            return "ASR provider error: \(underlying.localizedDescription)"
        }
    }
}
