import AppKit
import SwiftUI

// MARK: - SkillResultView

/// Floating panel showing skill output text with action buttons.
///
/// Follows `SkillSearchView` pattern: static window lifecycle,
/// `@State` ViewModel ownership, extracted child subviews. (Coupling)
///
/// Flutter orchestrates show/dismiss — this view only reports clicks. (Coupling)
struct SkillResultView: View {

    static let windowIdentifier = "skillResult"

    @State private var viewModel: SkillResultViewModel

    init(skillResult: SkillResult) {
        _viewModel = State(initialValue: SkillResultViewModel(skillResult: skillResult))
    }

    // MARK: - Window Lifecycle

    /// Present the SkillResult popup above the dock.
    static func showWindow(skillResult: SkillResult) {
        let config = WindowConfiguration(
            identifier: windowIdentifier,
            size: .zero,
            position: .screen(.bottomCenter, offset: CGPoint(x: 0, y: 80)),
            style: .nonActivatingPanel,
            sizingMode: .fitContent,
            usePanel: true
        )
        WindowManager.shared.showWindow(configuration: config) {
            SkillResultView(skillResult: skillResult)
        }
    }

    static func dismissWindow() {
        WindowManager.shared.closeWindow(identifier: windowIdentifier)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            TopBar(
                skillName: viewModel.skillResult.skillName,
                skillIcon: viewModel.skillResult.skillIcon,
                skillIconBytes: viewModel.skillResult.skillIconBytes,
                onDismiss: { viewModel.dismiss() }
            )

            ResultBody(text: viewModel.skillResult.resultText)

            ContextIconsRow(contexts: viewModel.skillResult.contexts)

            Divider()
                .background(Color.borderHard)

            ActionBar { actionId in
                viewModel.selectAction(actionId)
            }
        }
        .frame(width: 600)
        .coordinateSpace(name: "skillResultPanel")
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.backgroundHard)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.borderHard, lineWidth: 1)
                }
        }
    }
}

// MARK: - TopBar

/// Skill icon + name left-aligned, close button (X) top-right.
///
/// Extracted subview for optimal SwiftUI diffing — body skipped when inputs unchanged.
private struct TopBar: View {

    let skillName: String
    let skillIcon: String
    let skillIconBytes: Data?
    let onDismiss: () -> Void

    @State private var isDismissHovered = false

    var body: some View {
        HStack {
            skillIconView

            Text(skillName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.text2)

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.text4)
                    .frame(width: 24, height: 24)
                    .background {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isDismissHovered ? Color.backgroundSoft : Color.clear)
                    }
            }
            .buttonStyle(.plain)
            .onHover { isDismissHovered = $0 }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var skillIconView: some View {
        if let iconBytes = skillIconBytes, let nsImage = NSImage(data: iconBytes) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 14, height: 14)
        } else {
            Image(systemName: skillIcon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.text2)
        }
    }
}

// MARK: - ResultBody

/// Multi-line text display area for the skill result content.
///
/// Scrollable when content exceeds maxHeight.
private struct ResultBody: View {

    let text: String

    var body: some View {
        ScrollView {
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(Color.text1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .frame(maxHeight: 200)
    }
}

// MARK: - ContextIconsRow

/// Decorative row of small icons showing the context sources used to produce the result.
///
/// Right-aligned below the result text. SF Symbols render directly;
/// app icons resolve from bundle ID via `NSWorkspace`.
private struct ContextIconsRow: View {

    let contexts: [SkillResultContext]

    var body: some View {
        if !contexts.isEmpty {
            HStack(spacing: 8) {
                Spacer()

                ForEach(contexts) { context in
                    ContextIconItem(context: context)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
        }
    }
}

// MARK: - ContextIconItem

/// Single context icon with an animated hover tooltip.
///
/// Extracted subview so each icon tracks its own `isHovered` state independently.
/// Uses a background `GeometryReader` to measure position within a named coordinate
/// space (`"skillResultPanel"`) and shifts the tooltip left when it would overflow.
private struct ContextIconItem: View {

    let context: SkillResultContext

    @State private var isHovered = false
    @State private var iconMidX: CGFloat = 0
    @State private var tooltipWidth: CGFloat = 0

    /// Panel width constant — must match the `.frame(width:)` on `SkillResultView`.
    private let panelWidth: CGFloat = 600

    var body: some View {
        iconView
            .opacity(isHovered ? 1 : 0.5)
            .background {
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            iconMidX = geo.frame(in: .named("skillResultPanel")).midX
                        }
                }
            }
            .overlay(alignment: .top) {
                if isHovered {
                    tooltipLabel
                        .background {
                            GeometryReader { geo in
                                Color.clear
                                    .onAppear { tooltipWidth = geo.size.width }
                            }
                        }
                        .offset(x: tooltipOffsetX, y: -28)
                        .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .bottom)))
                }
            }
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .onHover { isHovered = $0 }
    }

    /// Shifts the tooltip left only when its trailing edge would overflow the panel.
    private var tooltipOffsetX: CGFloat {
        let halfTooltip = tooltipWidth / 2
        let rightEdge = iconMidX + halfTooltip
        let panelInset: CGFloat = 12

        if rightEdge > panelWidth - panelInset {
            return -(rightEdge - (panelWidth - panelInset))
        }
        return 0
    }

    private var tooltipLabel: some View {
        Text(context.name)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.text1)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.backgroundHard)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.borderHard, lineWidth: 1)
            }
    }

    @ViewBuilder
    private var iconView: some View {
        if let iconBytes = context.iconBytes, let nsImage = NSImage(data: iconBytes) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 16, height: 16)
                .clipShape(.rect(cornerRadius: 3))
        } else if context.type == "appIcon", let icon = resolvedAppIcon {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 16, height: 16)
                .clipShape(.rect(cornerRadius: 3))
        } else {
            Image(systemName: context.value)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.text3)
        }
    }

    private var resolvedAppIcon: NSImage? {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: context.value) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: appURL.path)
    }
}

// MARK: - ActionBar

/// Bottom area with 3 hardcoded action buttons.
///
/// "Continue in Chat" left-aligned, "Copy to clipboard" and "Paste" right-aligned.
private struct ActionBar: View {

    let onAction: (String) -> Void

    var body: some View {
        HStack(spacing: 16) {
            Spacer()

            ActionButton(
                label: "Continue in Chat",
                shortcut: "⌘J",
                actionId: "continueInChat",
                onAction: onAction
            )

            ActionButton(
                label: "Copy to clipboard",
                shortcut: "C",
                actionId: "copyToClipboard",
                onAction: onAction
            )

            ActionButton(
                label: "Paste",
                shortcut: "↵",
                actionId: "paste",
                onAction: onAction
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background {
            UnevenRoundedRectangle(bottomLeadingRadius: 12, bottomTrailingRadius: 12)
                .fill(Color.backgroundMedium)
        }
    }
}

// MARK: - ActionButton

/// Single action button with label and shortcut key caps.
///
/// Extracted subview — each button tracks its own hover state independently.
private struct ActionButton: View {

    let label: String
    let shortcut: String
    let actionId: String
    let onAction: (String) -> Void

    @State private var isHovered = false

    var body: some View {
        Button { onAction(actionId) } label: {
            HStack(spacing: 8) {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.text3)
                    .lineLimit(1)

                ShortcutKeyCaps(shortcut: shortcut)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? Color.backgroundSoft : Color.clear)
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - ShortcutKeyCaps

/// Renders each character of a shortcut string (e.g. "⌘J") as an individual key cap.
///
/// Duplicated from SkillSearchView (where it is `private`).
/// Same visual style: `text4` text, `backgroundSoft` fill, `borderHard` stroke.
private struct ShortcutKeyCaps: View {

    let shortcut: String

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(shortcut.enumerated()), id: \.offset) { _, char in
                Text(String(char))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.text4)
                    .frame(minWidth: 22, minHeight: 22)
                    .padding(.horizontal, 4)
                    .background {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.backgroundSoft)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.borderHard, lineWidth: 1)
                    }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct SkillResultView_Previews: PreviewProvider {
    static var previews: some View {
        SkillResultView(skillResult: SkillResult(
            id: "preview",
            skillName: "Dictation",
            skillIcon: "waveform",
            skillIconBytes: nil,
            resultText: "Hi there! I'm Jay and I'm testing out Shadow's newest feature right now and it seems pretty cool!",
            contexts: [
                SkillResultContext(id: "1", type: "sfSymbol", value: "waveform", name: "Microphone", iconBytes: nil),
                SkillResultContext(id: "2", type: "sfSymbol", value: "display", name: "Screen", iconBytes: nil),
                SkillResultContext(id: "3", type: "sfSymbol", value: "cursorarrow", name: "Cursor", iconBytes: nil),
                SkillResultContext(id: "4", type: "appIcon", value: "com.google.Chrome", name: "Google Chrome", iconBytes: nil),
            ]
        ))
        .background(Color.black)
    }
}
#endif
