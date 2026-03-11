import CoreAudio
import Foundation

// MARK: - CoreAudioError

/// Errors from CoreAudio device management operations.
///
/// Exhaustive enum with `LocalizedError` conformance.
/// Follows `ASRServiceError` and `AudioCaptureError` pattern. (Predictability)
enum CoreAudioError: Error, LocalizedError {

    /// CoreAudio returned an unexpected `OSStatus` error code.
    case osStatus(OSStatus, context: String)

    /// The requested device was not found by name or UID.
    case deviceNotFound(identifier: String)

    /// Attempted to start monitoring while already monitoring.
    case alreadyMonitoring

    /// Failed to set the system default input device.
    case setDefaultFailed(deviceName: String, status: OSStatus)

    var errorDescription: String? {
        switch self {
        case .osStatus(let status, let context):
            return "CoreAudio error \(status) during \(context)"
        case .deviceNotFound(let identifier):
            return "Audio device not found: \(identifier)"
        case .alreadyMonitoring:
            return "Device monitoring is already active. Call stopMonitoring() first."
        case .setDefaultFailed(let name, let status):
            return "Failed to set default input device to '\(name)' (OSStatus \(status))"
        }
    }
}

// MARK: - Flutter Error Code Mapping

extension CoreAudioError {

    /// Maps each case to a stable string code for `FlutterError`.
    /// Co-located with the error definition so they stay in sync. (Cohesion)
    var flutterErrorCode: String {
        switch self {
        case .osStatus:          "CORE_AUDIO_OS_STATUS"
        case .deviceNotFound:    "DEVICE_NOT_FOUND"
        case .alreadyMonitoring: "ALREADY_MONITORING"
        case .setDefaultFailed:  "SET_DEFAULT_FAILED"
        }
    }
}
