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

    private func scaleAmplitude(_ amplitude: Float, weight: Float) -> Float {
        guard displayMode == .transientHighlight else { return amplitude }
        return TransientScaler.scaleAmplitude(amplitude, weight: weight)
    }
}
