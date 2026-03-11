import Foundation

// MARK: - AccessibilityError

/// Errors from Accessibility domain operations: permission, keystroke simulation, clipboard.
///
/// Exhaustive enum with `LocalizedError` conformance.
/// Follows `CoreAudioError` and `AudioCaptureError` pattern. (Predictability)
enum AccessibilityError: Error, LocalizedError {

    /// The app does not have Accessibility permission.
    /// User must grant it in System Settings > Privacy & Security > Accessibility.
    case accessibilityPermissionDenied

    /// CGEvent creation failed (nil returned from CGEvent initializer).
    case keystrokeSimulationFailed(keyCode: UInt16)

    /// Clipboard read returned nil (no string content on clipboard).
    case clipboardReadFailed

    /// Clipboard write returned false (NSPasteboard.setString failed).
    case clipboardWriteFailed

    /// The copy operation timed out waiting for clipboard content to change.
    case copyTimedOut

    var errorDescription: String? {
        switch self {
        case .accessibilityPermissionDenied:
            return "Accessibility permission is required. Please enable it in System Settings > Privacy & Security > Accessibility."
        case .keystrokeSimulationFailed(let keyCode):
            return "Failed to create keyboard event for key code \(keyCode)."
        case .clipboardReadFailed:
            return "No text content found on the clipboard."
        case .clipboardWriteFailed:
            return "Failed to write text to the clipboard."
        case .copyTimedOut:
            return "Copy operation timed out waiting for clipboard content."
        }
    }
}

// MARK: - Flutter Error Code Mapping

extension AccessibilityError {

    /// Maps each case to a stable string code for `FlutterError`.
    /// Co-located with the error definition so they stay in sync. (Cohesion)
    var flutterErrorCode: String {
        switch self {
        case .accessibilityPermissionDenied: "ACCESSIBILITY_PERMISSION_DENIED"
        case .keystrokeSimulationFailed:     "KEYSTROKE_SIMULATION_FAILED"
        case .clipboardReadFailed:           "CLIPBOARD_READ_FAILED"
        case .clipboardWriteFailed:          "CLIPBOARD_WRITE_FAILED"
        case .copyTimedOut:                  "COPY_TIMED_OUT"
        }
    }
}
