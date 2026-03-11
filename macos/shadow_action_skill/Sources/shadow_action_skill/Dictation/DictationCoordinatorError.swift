import Foundation

// MARK: - DictationCoordinatorError

/// Errors from dictation lifecycle orchestration.
///
/// Follows the `ASRServiceError` / `AudioCaptureError` pattern:
/// exhaustive enum with `LocalizedError` conformance. (Predictability)
enum DictationCoordinatorError: Error, LocalizedError {

    /// Attempted to start dictation while a session is already in progress.
    case alreadyRunning

    /// The requested ASR provider is not registered in `ASRServiceFactory`.
    case unknownProvider(String)

    var errorDescription: String? {
        switch self {
        case .alreadyRunning:
            return "Dictation is already in progress. Call stopDictation first."
        case .unknownProvider(let name):
            return "Unknown ASR provider: \(name)"
        }
    }
}

// MARK: - Flutter Error Code Mapping

extension DictationCoordinatorError {

    /// Maps each case to a stable string code for `FlutterError`.
    /// Co-located with the error definition so they stay in sync. (Cohesion)
    var flutterErrorCode: String {
        switch self {
        case .alreadyRunning:  "ALREADY_RUNNING"
        case .unknownProvider: "UNKNOWN_PROVIDER"
        }
    }
}
