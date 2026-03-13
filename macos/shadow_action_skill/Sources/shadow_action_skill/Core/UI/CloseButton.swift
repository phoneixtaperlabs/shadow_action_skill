import SwiftUI

/// Reusable close (✕) button with hover background effect.
///
/// Owns its own `isHovered` state. Callers apply padding externally
/// since each view needs different padding (`.padding(8)`, `.padding(.top, 12)`, none).
struct CloseButton: View {

    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isHovered ? Color.text0 : Color.text4)
                .frame(width: 24, height: 24)
                .background {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isHovered ? Color.backgroundSoft : Color.clear)
                }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
