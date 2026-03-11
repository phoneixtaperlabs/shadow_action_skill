import Foundation

// MARK: - QuickAccessSkill

/// A single skill entry in the QuickAccess popup.
///
/// Decoded from the Flutter JSON payload. Immutable value type. (Predictability)
struct QuickAccessSkill: Identifiable, Equatable {
    /// Unique skill identifier (e.g. "dictation", "screenshot")
    let id: String
    /// Display name shown on hover (e.g. "Polish my write")
    let name: String
    /// Keyboard shortcut key label (e.g. "Q", "W", "E")
    let key: String
    /// SF Symbol name for fallback display (e.g. "mic.fill", "camera.fill")
    let icon: String?
    /// PNG image bytes rendered by Flutter (preferred over SF Symbol when present)
    let iconBytes: Data?
}

// MARK: - Defaults

extension QuickAccessSkill {
    /// The always-present search tile (last item, key "R").
    static let search = QuickAccessSkill(id: "search", name: "Search", key: "R", icon: "ellipsis", iconBytes: nil)
}

// MARK: - Flutter Parsing

extension QuickAccessSkill {
    /// Parse an array of skills from the Flutter JSON arguments.
    ///
    /// Expected format: `{"skills": [{"id": "...", "name": "...", "key": "...", "icon": "...", "iconBytes": Data}, ...]}`
    /// `icon` and `iconBytes` are both optional — at least one should be present.
    /// The router converts `FlutterStandardTypedData` → `Data` before this is called.
    /// Returns `nil` if the payload is malformed.
    static func fromFlutterArguments(_ arguments: Any?) -> [QuickAccessSkill]? {
        guard let dict = arguments as? [String: Any],
              let skillsArray = dict["skills"] as? [[String: Any]] else {
            return nil
        }
        return skillsArray.compactMap { item in
            guard let id = item["id"] as? String,
                  let name = item["name"] as? String,
                  let key = item["key"] as? String else {
                return nil
            }
            let icon = item["icon"] as? String
            let iconBytes = item["iconBytes"] as? Data
            return QuickAccessSkill(id: id, name: name, key: key, icon: icon, iconBytes: iconBytes)
        }
    }
}
