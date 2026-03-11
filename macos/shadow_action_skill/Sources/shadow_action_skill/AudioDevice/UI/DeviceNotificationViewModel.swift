import Foundation
import Observation

// MARK: - DeviceNotificationViewModel

/// View model for the "Using {DeviceName}" floating notification.
///
/// `@Observable` + `@MainActor` per project convention (mirrors DictationViewModel).
/// Minimal responsibility — owns only the auto-dismiss lifecycle. (Coupling)
@MainActor
@Observable
final class DeviceNotificationViewModel {

    /// The human-readable name of the active input device.
    let deviceName: String

    /// Drives the fade-in / fade-out animation.
    /// Starts `true`, transitions to `false` after the display duration elapses.
    private(set) var isVisible: Bool = true

    init(deviceName: String) {
        self.deviceName = deviceName
    }

    /// Hides the notification, triggering the fade-out animation in the view.
    func dismiss() {
        isVisible = false
    }
}
