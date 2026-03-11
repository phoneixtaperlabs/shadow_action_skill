import Foundation
import Observation
import OSLog

// MARK: - AudioDeviceSelectViewModel

/// View model for the audio input device picker.
///
/// `@Observable` + `@MainActor` per project convention.
/// Owns its own `CoreAudioService` instance to avoid lifecycle conflicts
/// with `DictationCoordinator`'s instance — CoreAudio HAL supports
/// multiple listeners safely. (Coupling — narrow)
@MainActor
@Observable
final class AudioDeviceSelectViewModel {

    // MARK: - Published State

    /// All physical input devices currently available.
    private(set) var inputDevices: [AudioDevice] = []

    /// The system's current default input device.
    private(set) var currentSystemDefault: AudioDevice?

    // MARK: - Dependencies

    private let coreAudioService = CoreAudioService()
    private let logger = Logger(subsystem: "shadow_action_skill", category: "AudioDeviceSelect")

    // MARK: - Monitoring Task

    private var monitoringTask: Task<Void, Never>?

    // MARK: - Computed

    /// The display name for the bottom indicator.
    var activeDeviceDisplayName: String {
        currentSystemDefault?.name ?? "No Device"
    }

    // MARK: - Lifecycle

    /// Begin streaming device changes. Called from `.task` in the view.
    func startMonitoring() async {
        // Load initial snapshot (works without monitoring).
        let snapshot = await coreAudioService.getDevices()
        applySnapshot(snapshot)

        // Start monitoring for hot-plug events.
        do {
            try await coreAudioService.startMonitoring()
        } catch {
            logger.warning("[AudioDeviceSelect] Failed to start monitoring: \(error)")
            return
        }

        monitoringTask = Task { [weak self] in
            guard let self else { return }
            for await snapshot in await self.coreAudioService.deviceStream {
                guard !Task.isCancelled else { break }
                self.applySnapshot(snapshot)
            }
        }
    }

    /// Stop monitoring. Called on view disappearance.
    func stopMonitoring() async {
        monitoringTask?.cancel()
        monitoringTask = nil
        await coreAudioService.stopMonitoring()
    }

    // MARK: - User Actions

    /// User tapped a device row. Changes the macOS system default input device.
    func selectDevice(_ device: AudioDevice) {
        Task {
            do {
                try await coreAudioService.setDefaultInputDevice(uid: device.uid)
            } catch {
                logger.warning("[AudioDeviceSelect] Failed to set default device '\(device.name)': \(error)")
            }
        }
        logger.info("[AudioDeviceSelect] Selected '\(device.name)' (uid: \(device.uid))")
    }

    /// Whether a device row should appear selected (matches current system default).
    func isDeviceSelected(_ device: AudioDevice) -> Bool {
        currentSystemDefault?.uid == device.uid
    }

    // MARK: - Private

    private func applySnapshot(_ snapshot: DeviceListSnapshot) {
        inputDevices = snapshot.inputDevices
        currentSystemDefault = snapshot.defaultInputDevice
    }
}
