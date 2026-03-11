import SwiftUI

// MARK: - SkillSearchView

/// Vertical skill list with a search field, displayed as a floating non-activating panel.
///
/// Flutter sends the full skill list; Swift filters locally by name.
/// Follows `QuickAccessView` pattern: static window lifecycle,
/// `@State` ViewModel ownership, extracted child subviews. (Coupling)
///
/// Flutter orchestrates show/dismiss — this view only reports clicks. (Coupling)
struct SkillSearchView: View {

    static let windowIdentifier = "skillSearch"

    @State private var viewModel: SkillSearchViewModel

    init(skills: [SkillSearchSkill]) {
        _viewModel = State(initialValue: SkillSearchViewModel(skills: skills))
    }

    // MARK: - Window Lifecycle

    /// Present the SkillSearch popup above the dock.
    static func showWindow(skills: [SkillSearchSkill]) {
        let config = WindowConfiguration(
            identifier: windowIdentifier,
            size: .zero,
            position: .screen(.bottomCenter, offset: CGPoint(x: 0, y: 80)),
            style: .nonActivatingKeyPanel,
            sizingMode: .fitContent,
            usePanel: true
        )
        WindowManager.shared.showWindow(configuration: config) {
            SkillSearchView(skills: skills)
        }
    }

    static func dismissWindow() {
        WindowManager.shared.closeWindow(identifier: windowIdentifier)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            SearchField(text: $viewModel.searchText)
                .padding(12)

            Divider()
                .background(Color.borderHard)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.filteredSkills) { skill in
                        SkillSearchRow(skill: skill) {
                            viewModel.selectSkill(skill)
                        }
                    }
                }
            }
            .frame(maxHeight: 300)
        }
        .frame(width: 500)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.backgroundHard)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.borderHard, lineWidth: 1)
        }
    }
}

// MARK: - SearchField

/// Search text field with magnifying glass icon.
private struct SearchField: View {

    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.text4)

            TextField("Search Skills...", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .foregroundStyle(Color.text1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - SkillSearchRow

/// Single skill row: icon, name, and shortcut key cap.
///
/// Extracted subview for optimal SwiftUI diffing — body skipped when inputs unchanged.
private struct SkillSearchRow: View {

    let skill: SkillSearchSkill
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                skillIcon
                    .frame(width: 28)

                Text(skill.name)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.text1)

                Spacer()

                ShortcutKeyCaps(shortcut: skill.shortcut)
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? Color.backgroundSoft : Color.clear)
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private var skillIcon: some View {
        if let iconBytes = skill.iconBytes, let nsImage = NSImage(data: iconBytes) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
        } else if let icon = skill.icon {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Color.text2)
        }
    }
}

// MARK: - ShortcutKeyCaps

/// Renders each character of a shortcut string (e.g. "⌘Q") as an individual key cap.
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
struct SkillSearchView_Previews: PreviewProvider {
    static var previews: some View {
        SkillSearchView(skills: [
            SkillSearchSkill(id: "dictation", name: "Dictation", icon: "waveform", shortcut: "⌘Q", iconBytes: nil),
            SkillSearchSkill(id: "quick_action", name: "Quick Action", icon: "bolt.fill", shortcut: "⌘W", iconBytes: nil),
            SkillSearchSkill(id: "ai_assist", name: "Polish my write", icon: "sparkles", shortcut: "⌘E", iconBytes: nil),
            SkillSearchSkill(id: "screenshot", name: "Screenshot", icon: "camera.fill", shortcut: "⌘T", iconBytes: nil),
            SkillSearchSkill(id: "translate", name: "Translate", icon: "globe", shortcut: "⌘Y", iconBytes: nil),
        ])
        .background(Color.black)
    }
}
#endif
