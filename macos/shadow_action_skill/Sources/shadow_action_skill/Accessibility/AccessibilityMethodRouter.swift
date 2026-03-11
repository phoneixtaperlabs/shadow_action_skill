import FlutterMacOS

// MARK: - AccessibilityMethodRouter

/// Routes Flutter method-channel calls to `AccessibilityService`.
///
/// Owns arg extraction, validation, `Task` wrapping, and error-to-`FlutterError` mapping.
/// Keeps `AccessibilityService` free of any `FlutterMacOS` dependency. (Coupling)
///
/// `enum` because no instances are needed — pure namespace for the static `handle` function.
@MainActor
enum AccessibilityMethodRouter {

    private static func flutterError(from error: Error) -> FlutterError {
        let code = (error as? AccessibilityError)?.flutterErrorCode ?? "UNKNOWN_ERROR"
        return FlutterError(code: code, message: error.localizedDescription, details: nil)
    }

    static func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let service = AccessibilityService.shared

        switch call.method {
        case "checkAccessibilityPermission":
            result(service.checkPermission())

        case "requestAccessibilityPermission":
            result(service.requestPermission())

        case "getClipboardContent":
            result(service.getClipboardContent())

        case "setClipboardContent":
            guard let text = (call.arguments as? [String: Any])?["text"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Missing 'text' argument", details: nil))
                return
            }
            do {
                try service.setClipboardContent(text)
                result(nil)
            } catch {
                result(flutterError(from: error))
            }

        case "copy":
            let selectAll = (call.arguments as? [String: Any])?["selectAll"] as? Bool ?? false
            Task {
                do {
                    let text = try await service.copy(selectAll: selectAll)
                    result(text)
                } catch {
                    result(flutterError(from: error))
                }
            }

        case "paste":
            guard let text = (call.arguments as? [String: Any])?["text"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Missing 'text' argument", details: nil))
                return
            }
            Task {
                do {
                    try await service.paste(text)
                    result(nil)
                } catch {
                    result(flutterError(from: error))
                }
            }

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
