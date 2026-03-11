import Foundation
import Observation

// MARK: - SkillSearchViewModel

/// View model for the SkillSearch popup.
///
/// Holds the full skill list from Flutter, filters locally by search text,
/// and reports selections back. No self-dismissal — Flutter orchestrates. (Coupling)
@MainActor
@Observable
final class SkillSearchViewModel {

    /// All skills received from Flutter.
    private let allSkills: [SkillSearchSkill]

    /// Current search query bound to the TextField.
    var searchText: String = ""

    /// Skills filtered by the current search query.
    /// Shows all skills when the query is empty.
    var filteredSkills: [SkillSearchSkill] {
        if searchText.isEmpty { return allSkills }
        return allSkills.filter { $0.name.localizedStandardContains(searchText) }
    }

    init(skills: [SkillSearchSkill]) {
        self.allSkills = skills
    }

    /// Called when a skill row is clicked.
    /// Reports the selection to Flutter. Flutter decides when to dismiss.
    func selectSkill(_ skill: SkillSearchSkill) {
        FlutterBridge.shared.send(
            "onSkillSearchSelected",
            arguments: ["skillId": skill.id, "shortcut": skill.shortcut]
        )
    }
}
