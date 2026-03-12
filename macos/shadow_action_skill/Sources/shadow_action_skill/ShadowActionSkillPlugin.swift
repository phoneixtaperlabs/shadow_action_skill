import Cocoa
import FlutterMacOS

public class ShadowActionSkillPlugin: NSObject, FlutterPlugin {

  private let dictationCoordinator = DictationCoordinator()

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "shadow_action_skill", binaryMessenger: registrar.messenger)
    let instance = ShadowActionSkillPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    FlutterBridge.shared.channel = channel
  }

  // Flutter guarantees `handle` is called on the main thread on macOS.
  // `assumeIsolated` bridges that runtime guarantee to the compiler so
  // Tasks in `routeMethodCall` inherit @MainActor without repeating the annotation.
  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    MainActor.assumeIsolated {
      routeMethodCall(call, result: result)
    }
  }

  @MainActor
  private func routeMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("macOS " + ProcessInfo.processInfo.operatingSystemVersionString)

    // MARK: Dictation
    case "startDictation", "stopDictation", "dismissDictationView",
         "muteSystemOutput", "restoreSystemVolume", "getDefaultInputDeviceName",
         "showDictationFail", "dismissDictationFail", "showAudioDeviceSelect", "dismissAudioDeviceSelect",
         "showDeviceNotification", "dismissDeviceNotification":
      DictationMethodRouter.handle(call, result: result, coordinator: dictationCoordinator)

    // MARK: Window / UI
    case "showGlowOverlay":
      GlowOverlayView.showWindow()
      result(nil)

    case "dismissGlowOverlay":
      GlowOverlayView.dismissWindow()
      result(nil)

    case "showActionSkillUnavailable":
      ActionSkillUnavailableView.showWindow()
      result(nil)

    case "dismissActionSkillUnavailable":
      ActionSkillUnavailableView.dismissWindow()
      result(nil)

    // MARK: QuickAccess
    case "showQuickAccess", "dismissQuickAccess":
      QuickAccessMethodRouter.handle(call, result: result)

    // MARK: SkillSearch
    case "showSkillSearch", "dismissSkillSearch":
      SkillSearchMethodRouter.handle(call, result: result)

    // MARK: SkillResult
    case "showSkillResult", "dismissSkillResult",
         "showCopyConfirmation", "dismissCopyConfirmation":
      SkillResultMethodRouter.handle(call, result: result)

    // MARK: Accessibility
    case "checkAccessibilityPermission", "requestAccessibilityPermission",
         "getClipboardContent", "setClipboardContent", "copy", "paste":
      AccessibilityMethodRouter.handle(call, result: result)

    // MARK: Screenshot
    case "captureScreenshot":
      ScreenshotMethodRouter.handle(call, result: result)

    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
