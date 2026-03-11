import SwiftUI

// MARK: - ActionSkillUnavailableView

/// Banner shown when action skills cannot be used during a meeting.
///
/// Static view — no ViewModel needed. Close (✕) button delegates to Flutter
/// via `FlutterBridge.send("onActionSkillUnavailableDismissed")`.
/// Flutter orchestrates window closing. (Coupling)
///
/// Follows `DictationFailView` pattern: `RoundedRectangle` cornerRadius 12,
/// `backgroundHard` fill, `borderHard` stroke. (Coupling)
struct ActionSkillUnavailableView: View {

    static let windowIdentifier = "actionSkillUnavailable"

    // MARK: - Window Lifecycle

    /// Present the banner above the dock. (Cohesion — view owns its presentation config)
    static func showWindow() {
        let config = WindowConfiguration(
            identifier: windowIdentifier,
            size: .zero,
            position: .screen(.bottomCenter, offset: CGPoint(x: 0, y: 130)),
            style: .floatingPanel,
            sizingMode: .fitContent,
            usePanel: true
        )
        WindowManager.shared.showWindow(configuration: config) {
            ActionSkillUnavailableView()
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
        .frame(width: 400)
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
        Text("Action Skills are unavailable during meetings")
            .font(.system(size: 15, weight: .light))
            .foregroundStyle(Color.text1)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Close Button

    private var closeButton: some View {
        Button(action: dismiss) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.text4)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(8)
    }

    // MARK: - Actions

    private func dismiss() {
        FlutterBridge.shared.send("onActionSkillUnavailableDismissed")
    }
}

// MARK: - Preview

#if DEBUG
struct ActionSkillUnavailableView_Previews: PreviewProvider {
    static var previews: some View {
        ActionSkillUnavailableView()
            .background(Color.black)
    }
}
#endif
