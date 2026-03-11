import Foundation
import Observation

// MARK: - SkillResultViewModel

/// View model for the SkillResult popup.
///
/// Holds result data from Flutter and reports action selections back.
/// No keyboard monitoring — Flutter handles all shortcut key events.
/// No self-dismissal — Flutter orchestrates window closing. (Coupling)
@MainActor
@Observable
final class SkillResultViewModel {

    /// The skill result data to display.
    let skillResult: SkillResult

    init(skillResult: SkillResult) {
        self.skillResult = skillResult
    }

    /// Called when an action button is clicked.
    /// Reports the action to Flutter. Flutter decides when to dismiss.
    func selectAction(_ actionId: String) {
        FlutterBridge.shared.send(
            "onSkillResultAction",
            arguments: ["actionId": actionId, "text": skillResult.resultText]
        )
    }

    /// Called when the close (X) button is clicked.
    func dismiss() {
        FlutterBridge.shared.send("onSkillResultDismissed")
    }
}
