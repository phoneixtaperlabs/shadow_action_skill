import FlutterMacOS

// MARK: - SkillResultMethodRouter

/// Routes Flutter method-channel calls for the SkillResult popup.
///
/// Owns arg extraction and error mapping.
/// Keeps `SkillResultView` free of any `FlutterMacOS` dependency. (Coupling)
@MainActor
enum SkillResultMethodRouter {

    static func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "showSkillResult":
            let converted = Self.convertIconBytes(call.arguments)
            guard let skillResult = SkillResult.fromFlutterArguments(converted) else {
                result(FlutterError(
                    code: "INVALID_ARGUMENTS",
                    message: "showSkillResult requires 'skillName', 'skillIcon', and 'resultText'",
                    details: nil
                ))
                return
            }
            SkillResultView.showWindow(skillResult: skillResult)
            result(nil)

        case "dismissSkillResult":
            SkillResultView.dismissWindow()
            result(nil)

        case "showCopyConfirmation":
            CopyConfirmationView.showWindow()
            result(nil)

        case "dismissCopyConfirmation":
            CopyConfirmationView.dismissWindow()
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// Convert `FlutterStandardTypedData` → `Data` for the skill icon and each context's icon
    /// so the model can parse `iconBytes` without importing FlutterMacOS.
    private static func convertIconBytes(_ arguments: Any?) -> Any? {
        guard var dict = arguments as? [String: Any] else {
            return arguments
        }

        // Top-level skill icon bytes
        if let typedData = dict["skillIconBytes"] as? FlutterStandardTypedData {
            dict["skillIconBytes"] = typedData.data
        }

        // Context icon bytes
        if let contextArray = dict["contexts"] as? [[String: Any]] {
            dict["contexts"] = contextArray.map { item -> [String: Any] in
                var converted = item
                if let typedData = item["iconBytes"] as? FlutterStandardTypedData {
                    converted["iconBytes"] = typedData.data
                }
                return converted
            }
        }

        return dict
    }
}
