import FlutterMacOS

// MARK: - DictationMethodRouter

/// Routes Flutter method-channel calls to `DictationCoordinator`.
///
/// Owns arg extraction, `Task` wrapping, and error-to-`FlutterError` mapping.
/// Keeps `DictationCoordinator` free of any `FlutterMacOS` dependency. (Coupling)
///
/// Accepts the coordinator as a parameter because it is not a singleton — the plugin owns the instance.
@MainActor
enum DictationMethodRouter {

    private static func flutterError(from error: Error) -> FlutterError {
        if let dictationError = error as? DictationCoordinatorError {
            return FlutterError(code: dictationError.flutterErrorCode, message: error.localizedDescription, details: nil)
        }
        if let coreAudioError = error as? CoreAudioError {
            return FlutterError(code: coreAudioError.flutterErrorCode, message: error.localizedDescription, details: nil)
        }
        return FlutterError(code: "UNKNOWN_ERROR", message: error.localizedDescription, details: nil)
    }

    static func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult, coordinator: DictationCoordinator) {
        switch call.method {

        // MARK: Dictation Lifecycle

        case "startDictation":
            let providerName = (call.arguments as? [String: Any])?["asrProvider"] as? String ?? "whisper"
            Task {
                do {
                    try await coordinator.start(providerName: providerName)
                    result(nil)
                } catch {
                    result(flutterError(from: error))
                }
            }

        case "stopDictation":
            Task {
                await coordinator.stop()
                result(nil)
            }

        case "dismissDictationView":
            coordinator.dismissUI()
            result(nil)

        // MARK: System Output Volume

        case "muteSystemOutput":
            Task {
                do {
                    try await coordinator.muteSystemOutput()
                    result(nil)
                } catch {
                    result(flutterError(from: error))
                }
            }

        case "restoreSystemVolume":
            Task {
                do {
                    try await coordinator.restoreSystemVolume()
                    result(nil)
                } catch {
                    result(flutterError(from: error))
                }
            }

        // MARK: Device Info

        case "getDefaultInputDeviceName":
            Task {
                let name = await coordinator.getDefaultInputDeviceName()
                result(name)
            }

        // MARK: Dictation UI

        case "showDictationFail":
            coordinator.showDictationFail()
            result(nil)

        case "dismissDictationFail":
            coordinator.dismissDictationFail()
            result(nil)

        case "showAudioDeviceSelect":
            coordinator.showAudioDeviceSelect()
            result(nil)

        case "dismissAudioDeviceSelect":
            coordinator.dismissAudioDeviceSelect()
            result(nil)

        case "showDeviceNotification":
            guard let deviceName = (call.arguments as? [String: Any])?["deviceName"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Missing 'deviceName' argument", details: nil))
                return
            }
            coordinator.showDeviceNotification(deviceName: deviceName)
            result(nil)

        case "dismissDeviceNotification":
            coordinator.dismissDeviceNotification()
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
