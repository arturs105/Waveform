import SwiftUI

/// Draws one clip's peak envelope, with an optional crisp outline. Fills inherit
/// the ambient `foregroundStyle`, so callers keep tinting the waveform as before.
struct Renderer: View {
    let waveformData: [SampleData]
    var style: WaveformStyle = .normal
    /// Horizontal scale applied to each sample index (default 1 = 1pt per sample).
    var xScale: CGFloat = 1
    /// Horizontal offset added after scaling (default 0).
    var xOffset: CGFloat = 0

    var body: some View {
        ZStack {
            shape

            if style.peakOutline {
                shape.stroke(lineWidth: 1)
            }
        }
    }

    private var shape: WaveformShape {
        WaveformShape(
            waveformData: waveformData,
            style: style,
            xScale: xScale,
            xOffset: xOffset
        )
    }
}
