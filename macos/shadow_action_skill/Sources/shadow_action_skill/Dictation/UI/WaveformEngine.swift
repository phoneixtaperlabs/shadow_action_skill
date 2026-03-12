import Foundation

// MARK: - WaveformPreset

/// Animation preset defining bar layout, timing, and keyframe data.
/// Ported from Lottie reference — pure data, no SwiftUI dependency.
struct WaveformPreset {
    let sourceFPS: Double
    let renderFPS: Double
    let loopFrames: Double
    let compositionSize: CGSize
    let baseBarSize: CGSize
    let barOffset: CGPoint
    let barScaleX: CGFloat
    let bars: [WaveformBar]

    static func lottieReference(renderFPS: Double = 60) -> WaveformPreset {
        WaveformPreset(
            sourceFPS: 24,
            renderFPS: renderFPS,
            loopFrames: 40,
            compositionSize: CGSize(width: 28, height: 28),
            baseBarSize: CGSize(width: 2, height: 14.312),
            barOffset: CGPoint(x: -12.188, y: 0.531),
            barScaleX: 1.2,
            bars: LottieReferenceBars.bars
        )
    }
}

// MARK: - WaveformBar

struct WaveformBar: Identifiable {
    let id: Int
    let layerPosition: CGPoint
    let layerScaleY: CGFloat
    let keyframes: [WaveformKeyframe]
}

// MARK: - WaveformKeyframe

struct WaveformKeyframe {
    let frame: Double
    let value: CGFloat
    let inTangent: CGPoint
    let outTangent: CGPoint
}

// MARK: - WaveformInterpolator

/// Cubic-bezier keyframe interpolation engine.
enum WaveformInterpolator {

    static func value(at frame: Double, in keyframes: [WaveformKeyframe]) -> CGFloat {
        guard keyframes.count > 1 else { return keyframes.first?.value ?? 100 }

        for index in 0..<(keyframes.count - 1) {
            let current = keyframes[index]
            let next = keyframes[index + 1]

            guard frame >= current.frame, frame <= next.frame else { continue }

            let span = next.frame - current.frame
            guard span > 0.0001 else { return current.value }

            let rawProgress = (frame - current.frame) / span
            let easedProgress = cubicBezierY(
                x: rawProgress,
                c1: current.outTangent,
                c2: next.inTangent
            )

            return lerp(current.value, next.value, t: CGFloat(easedProgress))
        }

        return keyframes.last?.value ?? 100
    }

    static func lerp(_ a: CGFloat, _ b: CGFloat, t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }

    // MARK: - Cubic Bezier

    private static func cubicBezierY(x: Double, c1: CGPoint, c2: CGPoint) -> Double {
        let clampedX = min(max(x, 0), 1)
        let solvedT = solveBezierParameter(
            x: clampedX,
            c1x: Double(c1.x),
            c2x: Double(c2.x)
        )
        return sampleBezier(solvedT, p1: Double(c1.y), p2: Double(c2.y))
    }

    private static func solveBezierParameter(x: Double, c1x: Double, c2x: Double) -> Double {
        var t = x

        // Newton-Raphson iterations
        for _ in 0..<6 {
            let xEstimate = sampleBezier(t, p1: c1x, p2: c2x) - x
            let derivative = sampleBezierDerivative(t, p1: c1x, p2: c2x)

            if abs(xEstimate) < 0.000001 { return t }
            if abs(derivative) < 0.000001 { break }

            t -= xEstimate / derivative
        }

        // Bisection fallback
        var lower = 0.0
        var upper = 1.0
        t = x

        for _ in 0..<14 {
            let estimate = sampleBezier(t, p1: c1x, p2: c2x)
            if abs(estimate - x) < 0.000001 { return t }

            if estimate < x { lower = t } else { upper = t }
            t = (lower + upper) * 0.5
        }

        return t
    }

    private static func sampleBezier(_ t: Double, p1: Double, p2: Double) -> Double {
        let u = 1.0 - t
        return (3.0 * u * u * t * p1) + (3.0 * u * t * t * p2) + (t * t * t)
    }

    private static func sampleBezierDerivative(_ t: Double, p1: Double, p2: Double) -> Double {
        let u = 1.0 - t
        return (3.0 * u * u * p1) + (6.0 * u * t * (p2 - p1)) + (3.0 * t * t * (1.0 - p2))
    }
}

// MARK: - Lottie Reference Keyframe Data

enum LottieReferenceBars {

    static func k(
        _ frame: Double,
        _ value: CGFloat,
        inY: CGFloat = 1,
        outY: CGFloat = 0
    ) -> WaveformKeyframe {
        WaveformKeyframe(
            frame: frame,
            value: value,
            inTangent: CGPoint(x: 0.667, y: inY),
            outTangent: CGPoint(x: 0.333, y: outY)
        )
    }

    static let bars: [WaveformBar] = {
        let bar1 = WaveformBar(
            id: 1,
            layerPosition: CGPoint(x: 15.125, y: 13.625),
            layerScaleY: 66.981,
            keyframes: [
                k(0, 100), k(5, 70), k(10, 50), k(15, 80),
                k(20, 160, inY: 0.954, outY: 0),
                k(25, 80, inY: -0.718, outY: -0.37),
                k(30, 90, inY: 1, outY: -0.859),
                k(35, 70), k(40, 90),
            ]
        )
        let bar2 = WaveformBar(
            id: 2,
            layerPosition: CGPoint(x: 22.562, y: 12.938),
            layerScaleY: 183.019,
            keyframes: [
                k(0, 100), k(5, 50), k(10, 80), k(15, 70),
                k(20, 40, inY: 0.877, outY: 0),
                k(25, 70, inY: 0.718, outY: 0.37),
                k(30, 80, inY: 1, outY: 0.282),
                k(35, 90), k(40, 100),
            ]
        )
        let bar3 = WaveformBar(
            id: 3,
            layerPosition: CGPoint(x: 30.188, y: 13.375),
            layerScaleY: 100.943,
            keyframes: [
                k(0, 100), k(5, 50), k(10, 60), k(15, 60),
                k(20, 50, inY: 1.37, outY: 0),
                k(25, 60, inY: -0.718, outY: -0.37),
                k(30, 70, inY: 1, outY: 0.215),
                k(35, 150), k(40, 90),
            ]
        )
        let bar4 = WaveformBar(
            id: 4,
            layerPosition: CGPoint(x: 37.312, y: 13.312),
            layerScaleY: 132.075,
            keyframes: [
                k(0, 100), k(5, 80), k(10, 70), k(15, 60),
                k(20, 70, inY: 0.926, outY: 0),
                k(25, 120, inY: 1.056, outY: -0.074),
                k(30, 70, inY: 1, outY: 0.282),
                k(35, 80), k(40, 90),
            ]
        )
        // Bars 5–8 mirror bars 4–1 for a symmetric waveform
        func mirrored(_ bar: WaveformBar, id: Int) -> WaveformBar {
            WaveformBar(id: id, layerPosition: bar.layerPosition, layerScaleY: bar.layerScaleY, keyframes: bar.keyframes)
        }
        return [bar1, bar2, bar3, bar4, mirrored(bar4, id: 5), mirrored(bar3, id: 6), mirrored(bar2, id: 7), mirrored(bar1, id: 8)]
    }()
}
