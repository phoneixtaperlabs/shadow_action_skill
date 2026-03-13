import SwiftUI

// MARK: - DictationView

/// Full pill-shaped dictation control that switches between listening and thinking phases.
///
/// - `.listening`: cancel button | waveform indicator | confirm button
/// - `.thinking`: "Thinking ..." text centered, no buttons
///
/// Owns its `DictationViewModel` via `@State` (not `@StateObject`),
/// and passes only narrow values to child subviews. (Coupling)
struct DictationView: View {

    @State private var viewModel = DictationViewModel()

    private var isListening: Bool { viewModel.phase == .listening }

    var body: some View {
        HStack(spacing: 8) {
            CancelButton(action: viewModel.cancel)
                .opacity(isListening ? 1 : 0)
                .frame(width: isListening ? nil : 0)
                .clipped()

            ZStack {
                DictationIndicatorView(rmsLevel: viewModel.rmsLevel, speakingThreshold: viewModel.speakingThreshold)
                    .opacity(isListening ? 1 : 0)
                ThinkingLabel()
                    .opacity(isListening ? 0 : 1)
            }
            .frame(minWidth: 80)

            ConfirmButton(action: viewModel.confirm)
                .opacity(isListening ? 1 : 0)
                .frame(width: isListening ? nil : 0)
                .clipped()
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.phase)
        .background {
            Capsule()
                .fill(Color.backgroundHard)
        }
        .overlay {
            Capsule()
                .strokeBorder(Color.borderSoft, lineWidth: 1)
        }
        .onAppear {
            WindowManager.shared.dictationViewModel = viewModel
        }
        .onDisappear {
            WindowManager.shared.dictationViewModel = nil
        }
    }
}

// MARK: - ThinkingLabel

/// Animated "Thinking ..." label with pulsing trailing dots.
private struct ThinkingLabel: View {

    @State private var dotCount = 0

    private let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 2) {
            Text("Thinking")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.text2)

            Text(String(repeating: ".", count: dotCount + 1))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.text3)
                .frame(width: 16, alignment: .leading)
        }
        .onReceive(timer) { _ in
            dotCount = (dotCount + 1) % 3
        }
    }
}

// MARK: - CancelButton

/// Extracted subview for optimal SwiftUI diffing — body skipped when inputs unchanged.
private struct CancelButton: View {

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.text3)
                .frame(width: 28, height: 28)
                .background {
                    Circle()
                        .fill(Color.backgroundSoft)
                }
                .overlay {
                    Circle()
                        .strokeBorder(Color.borderHard, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ConfirmButton

private struct ConfirmButton: View {

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.brandSecondary)
                .frame(width: 28, height: 28)
                .background {
                    Circle()
                        .fill(Color.backgroundSoft)
                }
                .overlay {
                    Circle()
                        .strokeBorder(Color.borderHard, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Equatable Conformance

extension DictationPhase: Equatable {}

// MARK: - Preview

#if DEBUG
struct DictationView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            DictationView()
            DictationView()
        }
        .frame(width: 320, height: 160)
        .background(Color.black)
    }
}
#endif
