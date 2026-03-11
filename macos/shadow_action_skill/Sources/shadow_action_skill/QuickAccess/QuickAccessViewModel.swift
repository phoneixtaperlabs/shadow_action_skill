import Foundation
import Observation

// MARK: - QuickAccessViewModel

/// View model for the QuickAccess popup.
///
/// Holds skill data from Flutter and reports selections back.
/// No keyboard monitoring — Flutter handles all shortcut key events.
/// No self-dismissal — Flutter orchestrates window closing. (Coupling)
@MainActor
@Observable
final class QuickAccessViewModel {

    /// Skills displayed in the popup (Flutter skills + hardcoded search tile).
    private(set) var skills: [QuickAccessSkill]

    init(skills: [QuickAccessSkill]) {
        self.skills = skills + [.search]
    }

    /// Called when a skill tile is clicked.
    /// Reports the selection to Flutter. Flutter decides when to dismiss.
    func selectSkill(_ skill: QuickAccessSkill) {
        FlutterBridge.shared.send(
            "onQuickAccessSkillSelected",
            arguments: ["skillId": skill.id, "key": skill.key]
        )
    }
}
