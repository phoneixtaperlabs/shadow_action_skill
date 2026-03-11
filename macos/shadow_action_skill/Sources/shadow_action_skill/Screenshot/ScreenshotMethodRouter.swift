import FlutterMacOS

// MARK: - ScreenshotMethodRouter

/// Routes Flutter method-channel calls to `ScreenshotService`.
///
/// Owns arg extraction, `Task` wrapping, and error-to-`FlutterError` mapping.
/// Keeps `ScreenshotService` free of any `FlutterMacOS` dependency. (Coupling)
///
/// `enum` because no instances are needed — pure namespace for the static `handle` function.
@MainActor
enum ScreenshotMethodRouter {

    private static func flutterError(from error: Error) -> FlutterError {
        let code = (error as? ScreenshotError)?.flutterErrorCode ?? "UNKNOWN_ERROR"
        return FlutterError(code: code, message: error.localizedDescription, details: nil)
    }

    static func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "captureScreenshot":
            let args = call.arguments as? [String: Any]
            let quality = args?["quality"] as? Double ?? 0.8
            let fileName = args?["fileName"] as? String
            Task {
                do {
                    let screenshot = try await ScreenshotService.captureScreenshot(quality: quality, fileName: fileName)
                    result(screenshot.toMap())
                } catch {
                    result(flutterError(from: error))
                }
            }

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
