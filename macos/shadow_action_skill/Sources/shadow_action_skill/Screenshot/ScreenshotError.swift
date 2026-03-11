import Foundation

// MARK: - ScreenshotError

/// Errors from screenshot capture operations: permission, display enumeration, capture, encoding, file I/O.
///
/// Exhaustive enum with `LocalizedError` conformance.
/// Follows `AccessibilityError` and `CoreAudioError` pattern. (Predictability)
enum ScreenshotError: Error, LocalizedError {

    /// Screen Recording permission has not been granted.
    /// User must enable it in System Settings > Privacy & Security > Screen Recording.
    case screenRecordingPermissionDenied

    /// No displays were found in `SCShareableContent.current.displays`.
    case noDisplayFound

    /// `SCScreenshotManager.captureImage` failed with an underlying ScreenCaptureKit error.
    case captureFailed(underlying: Error)

    /// Failed to create a JPEG representation from the captured `CGImage`.
    case jpegEncodingFailed

    /// Failed to write the JPEG data to disk.
    case fileWriteFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .screenRecordingPermissionDenied:
            return "Screen Recording permission is required. Please enable it in System Settings > Privacy & Security > Screen Recording."
        case .noDisplayFound:
            return "No displays available for screen capture."
        case .captureFailed(let underlying):
            return "Screen capture failed: \(underlying.localizedDescription)"
        case .jpegEncodingFailed:
            return "Failed to encode screenshot as JPEG."
        case .fileWriteFailed(let underlying):
            return "Failed to write screenshot to disk: \(underlying.localizedDescription)"
        }
    }
}

// MARK: - Flutter Error Code Mapping

extension ScreenshotError {

    /// Maps each case to a stable string code for `FlutterError`.
    /// Co-located with the error definition so they stay in sync. (Cohesion)
    var flutterErrorCode: String {
        switch self {
        case .screenRecordingPermissionDenied: "SCREEN_RECORDING_PERMISSION_DENIED"
        case .noDisplayFound:                  "NO_DISPLAY_FOUND"
        case .captureFailed:                   "CAPTURE_FAILED"
        case .jpegEncodingFailed:              "JPEG_ENCODING_FAILED"
        case .fileWriteFailed:                 "FILE_WRITE_FAILED"
        }
    }
}
