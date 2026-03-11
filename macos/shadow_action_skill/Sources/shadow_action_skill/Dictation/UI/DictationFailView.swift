import SwiftUI

// MARK: - DictationFailView

/// "We couldn't hear you" view shown when no speech is detected during dictation.
///
/// Two actions — both delegate to Flutter (views stay dumb):
/// - "Select microphone" button → `FlutterBridge.send("onSelectMicrophoneTapped")`
/// - Close (✕) button → `FlutterBridge.send("onDictationFailDismissed")`
///
/// Flutter orchestrates window closing via `dismissDictationFail` method channel call.
/// No ViewModel needed — static view with two event-only actions. (Coupling)
struct DictationFailView: View {

    static let windowIdentifier = "dictationFail"

    // MARK: - Window Lifecycle

    /// Present the fail view as a floating panel. (Cohesion — view owns its presentation config)
    static func showWindow() {
        let config = WindowConfiguration(
            identifier: windowIdentifier,
            size: .zero,
            position: .screenCenter,
            style: .floatingPanel,
            sizingMode: .fitContent,
            usePanel: true
        )
        WindowManager.shared.showWindow(configuration: config) {
            DictationFailView()
        }
    }

    static func dismissWindow() {
        WindowManager.shared.closeWindow(identifier: windowIdentifier)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            content
            closeButton
        }
        .frame(width: 320)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.backgroundHard)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.borderHard, lineWidth: 1)
        }
        .clipShape(.rect(cornerRadius: 12))
    }

    // MARK: - Content

    private var content: some View {
        VStack(spacing: 12) {
            Text("We couldn't hear you")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.text0)

            Text("We didn't pick up any speech from your microphone.")
                .font(.system(size: 13))
                .foregroundStyle(Color.text3)
                .multilineTextAlignment(.center)

            SelectMicrophoneButton(action: selectMicrophone)
                .padding(.top, 4)
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 20)
    }

    // MARK: - Close Button

    private var closeButton: some View {
        Button(action: close) {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.text4)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(8)
    }

    // MARK: - Actions

    private func selectMicrophone() {
        FlutterBridge.shared.send("onSelectMicrophoneTapped")
    }

    private func close() {
        FlutterBridge.shared.send("onDictationFailDismissed")
    }
}

// MARK: - SelectMicrophoneButton

/// "Select microphone" button with brand-colored border.
/// Extracted subview for optimal SwiftUI diffing. (Readability)
private struct SelectMicrophoneButton: View {

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Select microphone")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.brandSecondary)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.brandSecondary, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#if DEBUG
struct DictationFailView_Previews: PreviewProvider {
    static var previews: some View {
        DictationFailView()
            .frame(width: 360, height: 200)
            .background(Color.black)
    }
}
#endif
