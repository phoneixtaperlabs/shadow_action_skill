import Foundation

// MARK: - SkillSearchSkill

/// A single skill entry in the SkillSearch popup.
///
/// Decoded from the Flutter JSON payload. Immutable value type. (Predictability)
struct SkillSearchSkill: Identifiable, Equatable {
    /// Unique skill identifier (e.g. "dictation", "screenshot")
    let id: String
    /// Display name shown in the row (e.g. "Polish my write")
    let name: String
    /// SF Symbol name for fallback display (e.g. "mic.fill", "camera.fill")
    let icon: String?
    /// Keyboard shortcut for display (e.g. "⌘Q") — single combined string from Flutter
    let shortcut: String
    /// PNG image bytes rendered by Flutter (preferred over SF Symbol when present)
    let iconBytes: Data?
}

// MARK: - Flutter Parsing

extension SkillSearchSkill {
    /// Parse an array of skills from the Flutter JSON arguments.
    ///
    /// Expected format: `{"skills": [{"id": "...", "name": "...", "icon": "...", "shortcut": "⌘Q", "iconBytes": Data}, ...]}`
    /// `icon` and `iconBytes` are both optional — at least one should be present.
    /// The router converts `FlutterStandardTypedData` → `Data` before this is called.
    /// Returns `nil` if the payload is malformed.
    static func fromFlutterArguments(_ arguments: Any?) -> [SkillSearchSkill]? {
        guard let dict = arguments as? [String: Any],
              let skillsArray = dict["skills"] as? [[String: Any]] else {
            return nil
        }
        return skillsArray.compactMap { item in
            guard let id = item["id"] as? String,
                  let name = item["name"] as? String,
                  let shortcut = item["shortcut"] as? String else {
                return nil
            }
            let icon = item["icon"] as? String
            let iconBytes = item["iconBytes"] as? Data
            return SkillSearchSkill(id: id, name: name, icon: icon, shortcut: shortcut, iconBytes: iconBytes)
        }
    }
}
