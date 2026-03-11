import Foundation

// MARK: - SkillResultContext

/// A context source that contributed to producing the skill result.
///
/// Decorative only — displayed as small icons below the result text.
/// Two types: SF Symbols (rendered directly) and app icons (resolved via bundle ID).
struct SkillResultContext: Identifiable, Equatable {
    let id: String
    /// `"sfSymbol"` or `"appIcon"`
    let type: String
    /// SF Symbol name (when type is `"sfSymbol"`) or app bundle ID (when type is `"appIcon"`)
    let value: String
    /// Human-readable label shown in the hover tooltip (e.g. "Microphone", "Google Chrome")
    let name: String
    /// PNG image bytes rendered by Flutter. When present, rendered instead of SF Symbol / app icon.
    let iconBytes: Data?
}

// MARK: - SkillResult

/// Data payload for the SkillResult popup.
///
/// Decoded from the Flutter JSON payload. Immutable value type. (Predictability)
struct SkillResult: Identifiable, Equatable {
    /// Auto-generated unique ID for SwiftUI identity.
    let id: String
    /// Display name of the skill that produced this result (e.g. "Dictation")
    let skillName: String
    /// SF Symbol name for the skill icon (e.g. "waveform")
    let skillIcon: String
    /// PNG image bytes for the skill icon. Preferred over [skillIcon] when present.
    let skillIconBytes: Data?
    /// The result text to display
    let resultText: String
    /// Context sources that contributed to this result (decorative icons)
    let contexts: [SkillResultContext]
}

// MARK: - Flutter Parsing

extension SkillResult {
    /// Parse a single SkillResult from Flutter JSON arguments.
    ///
    /// Expected format:
    /// ```json
    /// {
    ///   "skillName": "Dictation",
    ///   "skillIcon": "waveform",
    ///   "skillIconBytes": Data,
    ///   "resultText": "Hello...",
    ///   "contexts": [{"type": "sfSymbol", "value": "waveform", "name": "Mic", "iconBytes": Data}, ...]
    /// }
    /// ```
    /// `skillIconBytes`, context `iconBytes`, and `contexts` itself are all optional.
    /// The router converts `FlutterStandardTypedData` → `Data` before this is called.
    /// Returns `nil` if the payload is malformed.
    static func fromFlutterArguments(_ arguments: Any?) -> SkillResult? {
        guard let dict = arguments as? [String: Any],
              let skillName = dict["skillName"] as? String,
              let skillIcon = dict["skillIcon"] as? String,
              let resultText = dict["resultText"] as? String else {
            return nil
        }

        let skillIconBytes = dict["skillIconBytes"] as? Data

        var contexts: [SkillResultContext] = []
        if let contextList = dict["contexts"] as? [[String: Any]] {
            contexts = contextList.compactMap { item in
                guard let type = item["type"] as? String,
                      let value = item["value"] as? String,
                      let name = item["name"] as? String else { return nil }
                let iconBytes = item["iconBytes"] as? Data
                return SkillResultContext(id: UUID().uuidString, type: type, value: value, name: name, iconBytes: iconBytes)
            }
        }

        return SkillResult(
            id: UUID().uuidString,
            skillName: skillName,
            skillIcon: skillIcon,
            skillIconBytes: skillIconBytes,
            resultText: resultText,
            contexts: contexts
        )
    }
}
