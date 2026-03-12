import Foundation
import Observation

// MARK: - DictationPhase

/// What the dictation pill is currently showing.
/// Discriminated union — makes impossible states impossible. (Predictability)
enum DictationPhase {
    /// Mic is active, waveform/dots visible, cancel + confirm buttons shown.
    case listening
    /// Audio stopped, waiting for ASR to finish. "Thinking ..." shown, no buttons.
    case thinking
}

// MARK: - DictationViewModel

/// View model for the dictation UI.
///
/// `@Observable` + `@MainActor` per SwiftUI best practice.
/// Kept minimal — actual dictation lifecycle wiring is handled by the plugin layer.
@MainActor
@Observable
final class DictationViewModel {

    /// Current phase of the dictation UI.
    var phase: DictationPhase = .listening

    /// Current microphone RMS level (0.0 = silent, 1.0 = loud).
    /// Drives the dots ↔ waveform morph in `DictationIndicatorView`.
    var rmsLevel: CGFloat = 0

    /// Calibrated speaking threshold. Set by `DictationCoordinator` after sampling
    /// ambient noise at session start. Defaults to 0.35 until calibration completes.
    var speakingThreshold: CGFloat = 0.35

    /// Cancel the current dictation session — notifies Flutter to tear down the pipeline.
    func cancel() {
        FlutterBridge.shared.send("onDictationCancelled")
    }

    /// Confirm/accept the transcription — notifies Flutter to proceed with the result.
    func confirm() {
        FlutterBridge.shared.send("onDictationConfirmed")
    }
}
