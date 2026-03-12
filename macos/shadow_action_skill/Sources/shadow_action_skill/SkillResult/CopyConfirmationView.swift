import SwiftUI

// MARK: - CopyConfirmationView

/// Banner confirming text was copied to clipboard.
///
/// Visually identical to `ActionSkillUnavailableView` but with a checkmark icon
/// and "Copied. Paste anywhere." text.
///
/// Auto-dismisses after 2.5 seconds with fade-out animation, or immediately
/// via the close (✕) button. Both paths notify Flutter via
/// `FlutterBridge.send("onCopyConfirmationDismissed")`. (Coupling)
struct CopyConfirmationView: View {

    static let windowIdentifier = "copyConfirmation"

    @State private var isVisible = true

    // MARK: - Window Lifecycle

    /// Present the confirmation banner above the dock.
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
            CopyConfirmationView()
        }
    }

    static func dismissWindow() {
        WindowManager.shared.closeWindow(identifier: windowIdentifier)
    }

    // MARK: - Body

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
                .strokeBorder(Color.borderSoft, lineWidth: 1)
        }
        .clipShape(.rect(cornerRadius: 12))
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : -8)
        .animation(.easeInOut(duration: 0.3), value: isVisible)
        .task {
            try? await Task.sleep(for: .seconds(2.5))
            dismiss()
            // Allow fade-out animation to complete before closing the window.
            try? await Task.sleep(for: .seconds(0.35))
            Self.dismissWindow()
        }
    }

    // MARK: - Content

    private var content: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.text1)

            Text("Copied. Paste anywhere.")
                .font(.system(size: 15, weight: .light))
                .foregroundStyle(Color.text0)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Close Button

    private var closeButton: some View {
        Button(action: {
            dismiss()
            Self.dismissWindow()
        }) {
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
        isVisible = false
        FlutterBridge.shared.send("onCopyConfirmationDismissed")
    }
}

// MARK: - Preview

#if DEBUG
struct CopyConfirmationView_Previews: PreviewProvider {
    static var previews: some View {
        CopyConfirmationView()
            .background(Color.black)
    }
}
#endif
