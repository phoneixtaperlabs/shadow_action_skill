import SwiftUI

// MARK: - DictationIndicatorView

/// Displays 4 bars that morph between static dots (silent) and animated waveform bars (speaking).
///
/// Receives only `rmsLevel` — narrow dependency avoids unnecessary redraws
/// from unrelated viewmodel changes. (Coupling)
struct DictationIndicatorView: View {

    /// Microphone RMS level (0.0 = silent, 1.0 = loud).
    let rmsLevel: CGFloat

    // MARK: - Configuration

    private let preset = WaveformPreset.lottieReference()
    private let barWidth: CGFloat = 3
    private let barSpacing: CGFloat = 4
    private let barCount = 4
    private let maxBarHeight: CGFloat = 20
    private let speakingThreshold: CGFloat = 0.02
    /// How long to keep bars alive after RMS drops below threshold.
    /// Bridges natural speech pauses (~200-400ms between words).
    private let holdoverDuration: TimeInterval = 0.35

    // MARK: - Private State

    @State private var startedAt = Date()
    @State private var morphProgress: CGFloat = 0
    @State private var isSpeaking = false
    @State private var silenceTask: Task<Void, Never>?

    // MARK: - Body

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / preset.renderFPS)) { timeline in
            let elapsed = max(0, timeline.date.timeIntervalSince(startedAt))
            let frame = (elapsed * preset.sourceFPS)
                .truncatingRemainder(dividingBy: preset.loopFrames)

            HStack(spacing: barSpacing) {
                ForEach(preset.bars) { bar in
                    let animatedScaleY = WaveformInterpolator.value(
                        at: frame,
                        in: bar.keyframes
                    )

                    // Animated bar height = keyframe value × layer scale × RMS amplitude
                    // rmsLevel is already perceptually normalized (0–1) by AudioCaptureService
                    let normalizedScale = (animatedScaleY / 100.0) * (bar.layerScaleY / 100.0)
                    let rmsAmplitude = max(0.3, min(1.0, rmsLevel))
                    let animatedHeight = min(maxBarHeight, maxBarHeight * normalizedScale * rmsAmplitude)

                    // Dot height = bar width (perfect circle)
                    let dotHeight = barWidth

                    // Morph: lerp between dot and bar based on morphProgress
                    let displayHeight = WaveformInterpolator.lerp(
                        dotHeight,
                        animatedHeight,
                        t: morphProgress
                    )

                    RoundedRectangle(cornerRadius: barWidth / 2, style: .continuous)
                        .fill(Color.brandSecondary)
                        .frame(width: barWidth, height: max(barWidth, displayHeight))
                }
            }
        }
        .onAppear {
            startedAt = Date()
        }
        .onChange(of: rmsLevel) {
            let aboveThreshold = rmsLevel > speakingThreshold

            if aboveThreshold {
                // Sound detected — cancel any pending silence transition, go to bars immediately
                silenceTask?.cancel()
                silenceTask = nil
                if !isSpeaking {
                    isSpeaking = true
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        morphProgress = 1
                    }
                }
            } else if isSpeaking && silenceTask == nil {
                // RMS dropped — wait a beat before collapsing to dots (bridges speech pauses)
                silenceTask = Task {
                    try? await Task.sleep(for: .seconds(holdoverDuration))
                    guard !Task.isCancelled else { return }
                    isSpeaking = false
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        morphProgress = 0
                    }
                    silenceTask = nil
                }
            }
        }
    }
}
