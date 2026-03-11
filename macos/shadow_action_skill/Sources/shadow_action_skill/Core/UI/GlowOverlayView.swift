import SwiftUI

// MARK: - GlowOverlayView

/// Full-screen click-through overlay that renders a subtle orange vignette glow
/// around the screen edges. Uses `WindowStyle.overlay` so all mouse events pass
/// through to windows below.
///
/// Animation: fades in on appear via `withAnimation`, then breathes continuously
/// via `phaseAnimator`. (Readability — animation strategy is declarative)
///
/// Flutter-controlled lifecycle via `showGlowOverlay` / `dismissGlowOverlay`
/// method channel calls. (Coupling — view stays dumb, Flutter orchestrates)
struct GlowOverlayView: View {

    static let windowIdentifier = "glowOverlay"

    // MARK: - Window Lifecycle

    static func showWindow() {
        guard let screen = NSScreen.main else { return }
        let config = WindowConfiguration(
            identifier: windowIdentifier,
            size: screen.frame.size,
            position: .absolute(screen.frame.origin),
            style: .overlay,
            usePanel: true
        )
        WindowManager.shared.showWindow(configuration: config) {
            GlowOverlayView()
        }
    }

    static func dismissWindow() {
        WindowManager.shared.closeWindow(identifier: windowIdentifier)
    }

    // MARK: - Glow Configuration

    /// Peak opacity of the outermost glow edge.
    private static let intensity: Double = 0.25

    private let glowColor = Color.brandSecondary

    // MARK: - State

    @State private var isActive = false

    // MARK: - Body

    var body: some View {
        glowGradient
            .opacity(isActive ? 1 : 0)
            .modifier(BreathingModifier(isActive: isActive))
            .ignoresSafeArea()
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5)) {
                    isActive = true
                }
            }
    }

    // MARK: - Glow Depth

    /// How far each edge glow extends inward (fraction of that dimension).
    private static let edgeDepth: CGFloat = 0.08

    // MARK: - Subviews

    /// Layered gradients: EllipticalGradient for corners + 4 LinearGradients
    /// for uniform edge coverage. The ellipse alone leaves top/bottom/left/right
    /// midpoints too dim. (Readability — each gradient has one job)
    private var glowGradient: some View {
        ZStack {
            cornerGlow
            edgeGlow(.top)
            edgeGlow(.bottom)
            edgeGlow(.leading)
            edgeGlow(.trailing)
        }
    }

    /// Elliptical vignette — strongest at corners where two edges meet.
    private var cornerGlow: some View {
        EllipticalGradient(
            stops: [
                .init(color: .clear, location: 0.0),
                .init(color: .clear, location: 0.6),
                .init(color: glowColor.opacity(Self.intensity * 0.15), location: 0.75),
                .init(color: glowColor.opacity(Self.intensity * 0.4), location: 0.9),
                .init(color: glowColor.opacity(Self.intensity * 0.7), location: 1.0),
            ],
            center: .center,
            startRadiusFraction: 0.0,
            endRadiusFraction: 1.0
        )
    }

    /// Linear gradient for a single edge — fills in the midpoints the ellipse misses.
    private func edgeGlow(_ edge: Edge) -> some View {
        let isVertical = (edge == .top || edge == .bottom)

        return LinearGradient(
            stops: [
                .init(color: glowColor.opacity(Self.intensity), location: 0.0),
                .init(color: glowColor.opacity(Self.intensity * 0.3), location: 0.5),
                .init(color: .clear, location: 1.0),
            ],
            startPoint: unitPoint(for: edge),
            endPoint: unitPoint(for: edge.opposite)
        )
        .frame(
            maxWidth: isVertical ? .infinity : nil,
            maxHeight: isVertical ? nil : .infinity
        )
        .containerRelativeFrame(isVertical ? .vertical : .horizontal) { length, _ in
            length * Self.edgeDepth
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: alignment(for: edge)
        )
    }

    private func unitPoint(for edge: Edge) -> UnitPoint {
        switch edge {
        case .top: .top
        case .bottom: .bottom
        case .leading: .leading
        case .trailing: .trailing
        }
    }

    private func alignment(for edge: Edge) -> Alignment {
        switch edge {
        case .top: .top
        case .bottom: .bottom
        case .leading: .leading
        case .trailing: .trailing
        }
    }
}

// MARK: - BreathingModifier

/// Continuous opacity pulse via `phaseAnimator`. Separated to scope the
/// animation narrowly — only applies when `isActive` is true.
/// `.opacity()` is GPU-accelerated, so animating it is cheap. (Readability)
private struct BreathingModifier: ViewModifier {

    let isActive: Bool

    func body(content: Content) -> some View {
        if isActive {
            content
                .phaseAnimator([0.8, 1.0, 0.8]) { view, phase in
                    view.opacity(phase)
                } animation: { _ in
                    .easeInOut(duration: 1.8)
                }
        } else {
            content
        }
    }
}

// MARK: - Edge+Opposite

private extension Edge {
    var opposite: Edge {
        switch self {
        case .top: .bottom
        case .bottom: .top
        case .leading: .trailing
        case .trailing: .leading
        }
    }
}

// MARK: - Preview

#if DEBUG
struct GlowOverlayView_Previews: PreviewProvider {
    static var previews: some View {
        GlowOverlayView()
            .frame(width: 800, height: 500)
            .background(Color.black)
    }
}
#endif
