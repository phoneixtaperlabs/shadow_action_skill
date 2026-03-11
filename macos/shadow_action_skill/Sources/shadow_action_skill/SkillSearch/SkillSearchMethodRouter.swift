import FlutterMacOS

// MARK: - SkillSearchMethodRouter

/// Routes Flutter method-channel calls for the SkillSearch popup.
///
/// Owns arg extraction and error mapping.
/// Keeps `SkillSearchView` free of any `FlutterMacOS` dependency. (Coupling)
@MainActor
enum SkillSearchMethodRouter {

    static func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "showSkillSearch":
            let converted = Self.convertIconBytes(call.arguments)
            guard let skills = SkillSearchSkill.fromFlutterArguments(converted),
                  !skills.isEmpty else {
                result(FlutterError(
                    code: "INVALID_ARGUMENTS",
                    message: "showSkillSearch requires a non-empty 'skills' array",
                    details: nil
                ))
                return
            }
            SkillSearchView.showWindow(skills: skills)
            result(nil)

        case "dismissSkillSearch":
            SkillSearchView.dismissWindow()
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// Convert `FlutterStandardTypedData` → `Data` in the skills array
    /// so the model can parse `iconBytes` without importing FlutterMacOS.
    private static func convertIconBytes(_ arguments: Any?) -> Any? {
        guard var dict = arguments as? [String: Any],
              let skillsArray = dict["skills"] as? [[String: Any]] else {
            return arguments
        }
        dict["skills"] = skillsArray.map { item -> [String: Any] in
            var converted = item
            if let typedData = item["iconBytes"] as? FlutterStandardTypedData {
                converted["iconBytes"] = typedData.data
            }
            return converted
        }
        return dict
    }
}
