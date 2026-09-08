import SwiftUI

/// The filled peak envelope of a waveform.
struct WaveformShape: Shape {
    let waveformData: [SampleData]
    var style: WaveformStyle = .normal
    /// Horizontal scale applied to each sample index (default 1 = 1pt per sample).
    var xScale: CGFloat = 1
    /// Horizontal offset added after scaling (default 0).
    var xOffset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: xOffset, y: rect.midY))

            for index in 0..<waveformData.count {
                let x = CGFloat(index) * xScale + xOffset
                let sample = waveformData[index]
                let value = AmplitudeMapper.map(sample.max, weight: sample.transientWeight, style: style)
                path.addLine(to: CGPoint(x: x, y: rect.midY + rect.midY * CGFloat(value)))
            }

            for index in (0..<waveformData.count).reversed() {
                let x = CGFloat(index) * xScale + xOffset
                let sample = waveformData[index]
                let value = AmplitudeMapper.map(sample.min, weight: sample.transientWeight, style: style)
                path.addLine(to: CGPoint(x: x, y: rect.midY + rect.midY * CGFloat(value)))
            }

            path.closeSubpath()
        }
    }
}
