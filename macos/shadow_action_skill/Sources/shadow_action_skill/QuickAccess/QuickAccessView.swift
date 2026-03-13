import AppKit
import SwiftUI

// MARK: - QuickAccessView

/// Horizontal row of skill tiles displayed as a floating non-activating panel.
///
/// Each tile shows a shortcut key label and an SF Symbol icon.
/// The last tile (R / Search) is always appended by the ViewModel.
///
/// Follows `DictationView` pattern: static window lifecycle,
/// `@State` ViewModel ownership, extracted child subviews. (Coupling)
///
/// Flutter orchestrates show/dismiss — this view only reports clicks. (Coupling)
struct QuickAccessView: View {

    static let windowIdentifier = "quickAccess"

    @State private var viewModel: QuickAccessViewModel
    @State private var panelWidth: CGFloat = 0

    init(skills: [QuickAccessSkill]) {
        _viewModel = State(initialValue: QuickAccessViewModel(skills: skills))
    }

    // MARK: - Window Lifecycle

    /// Present the QuickAccess popup above the dock.
    static func showWindow(skills: [QuickAccessSkill]) {
        let config = WindowConfiguration(
            identifier: windowIdentifier,
            size: .zero,
            position: .screen(.bottomCenter, offset: CGPoint(x: 0, y: 80)),
            style: .nonActivatingPanel,
            sizingMode: .fitContent,
            usePanel: true
        )
        WindowManager.shared.showWindow(configuration: config) {
            QuickAccessView(skills: skills)
        }
    }

    static func dismissWindow() {
        WindowManager.shared.closeWindow(identifier: windowIdentifier)
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 6) {
            ForEach(viewModel.skills) { skill in
                SkillTile(skill: skill, panelWidth: panelWidth) {
                    viewModel.selectSkill(skill)
                }
            }
        }
        .padding(6)
        .padding(.top, 36)
        .background {
            GeometryReader { geo in
                Color.clear
                    .onAppear { panelWidth = geo.size.width }
            }
        }
        .coordinateSpace(name: "quickAccessPanel")
    }
}

// MARK: - SkillTile

/// Single skill tile: key label in top-right, icon in bottom-left.
/// Shows a tooltip with the skill name on hover.
///
/// Extracted subview for optimal SwiftUI diffing — body skipped when inputs unchanged.
private struct SkillTile: View {

    let skill: QuickAccessSkill
    let panelWidth: CGFloat
    let action: () -> Void

    @State private var isHovered = false
    @State private var tileMidX: CGFloat = 0
    @State private var tooltipWidth: CGFloat = 0

    var body: some View {
        Button(action: action) {
            ZStack {
                Group {
                    if let iconBytes = skill.iconBytes, let nsImage = NSImage(data: iconBytes) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 14, height: 14)
                    } else if let icon = skill.icon {
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.text2)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(6)

                Text(skill.key)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.brandPrimary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(5)
            }
            .frame(width: 48, height: 48)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.backgroundTile)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.borderHard, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .background {
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        tileMidX = geo.frame(in: .named("quickAccessPanel")).midX
                    }
            }
        }
        .overlay(alignment: .top) {
            SkillTooltip(name: skill.name)
                .background {
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { tooltipWidth = geo.size.width }
                    }
                }
                .offset(x: tooltipOffsetX, y: -36)
                .opacity(isHovered ? 1 : 0)
                .animation(.easeInOut(duration: 0.15), value: isHovered)
                .allowsHitTesting(false)
        }
    }

    /// Shifts the tooltip so it stays within the panel bounds.
    private var tooltipOffsetX: CGFloat {
        guard panelWidth > 0 else { return 0 }
        let halfTooltip = tooltipWidth / 2
        let inset: CGFloat = 6

        // Overflow right
        let rightEdge = tileMidX + halfTooltip
        if rightEdge > panelWidth - inset {
            return -(rightEdge - (panelWidth - inset))
        }

        // Overflow left
        let leftEdge = tileMidX - halfTooltip
        if leftEdge < inset {
            return inset - leftEdge
        }

        return 0
    }
}

// MARK: - SkillTooltip

/// Tooltip label shown on hover above a skill tile.
private struct SkillTooltip: View {

    let name: String

    var body: some View {
        Text(name)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color.text1)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.backgroundHard)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.borderHard, lineWidth: 1)
            }
            .fixedSize()
    }
}

// MARK: - Preview

#if DEBUG
struct QuickAccessView_Previews: PreviewProvider {
    static var previews: some View {
        QuickAccessView(skills: [
            QuickAccessSkill(id: "dictation", name: "Dictation", key: "Q", icon: "waveform", iconBytes: nil),
            QuickAccessSkill(id: "quick_action", name: "Quick Action", key: "W", icon: "bolt.fill", iconBytes: nil),
            QuickAccessSkill(id: "ai_assist", name: "Polish my write", key: "E", icon: "sparkles", iconBytes: nil),
        ])
        .background(Color.black)
    }
}
#endif
