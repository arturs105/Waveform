import SwiftUI

struct Renderer: Shape {
    let waveformData: [SampleData]
    var displayMode: WaveformDisplayMode = .normal

    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: 0, y: rect.midY))

            for index in 0..<waveformData.count {
                let x = CGFloat(index)
                let sample = waveformData[index]
                let scaledMax = scaleAmplitude(sample.max, weight: sample.transientWeight)
                let maxY = rect.midY + (rect.midY * CGFloat(scaledMax))
                path.addLine(to: CGPoint(x: x, y: maxY))
            }

            for index in (0..<waveformData.count).reversed() {
                let x = CGFloat(index)
                let sample = waveformData[index]
                let scaledMin = scaleAmplitude(sample.min, weight: sample.transientWeight)
                let minY = rect.midY + (rect.midY * CGFloat(scaledMin))
                path.addLine(to: CGPoint(x: x, y: minY))
            }

            path.closeSubpath()
        }
    }

    /// Minimum amplitude multiplier for non-transient samples
    private static let nonTransientAttenuation: Float = 0.15

    /// Power curve exponent for transient emphasis (higher = more compression)
    private static let transientExpansionExponent: Float = 1.5

    private func scaleAmplitude(_ amplitude: Float, weight: Float) -> Float {
        guard displayMode == .transientHighlight else { return amplitude }

        // Two-part scaling:
        // 1. Attenuate non-transients (low weight → smaller amplitude)
        // 2. Compress dynamic range for transients (high weight → values pulled toward 1.0)

        let attenuation = Self.nonTransientAttenuation + weight * (1.0 - Self.nonTransientAttenuation)

        // Power curve: compresses dynamic range, making transients more visible
        let scaleFactor = 1.0 / (1.0 + weight * Self.transientExpansionExponent)
        let absAmp = abs(amplitude)
        let expanded = pow(absAmp, scaleFactor)

        let scaled = expanded * attenuation
        return amplitude >= 0 ? scaled : -scaled
    }
}
