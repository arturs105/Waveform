import SwiftUI

/// Displays a waveform for a single clip positioned within a timeline viewport.
/// No gesture handling — purely a render view.
public struct ClipWaveformView: View {
    @ObservedObject var renderer: ClipRenderer
    let viewport: TimelineViewport
    let clip: ClipDescriptor
    /// How far past the frame the waveform may draw on each side (see
    /// `HorizontalOverdraw`). The frame — and so the viewport mapping — is
    /// unchanged; only the clip widens.
    let overdraw: HorizontalOverdraw

    public init(
        renderer: ClipRenderer,
        viewport: TimelineViewport,
        clip: ClipDescriptor,
        overdraw: HorizontalOverdraw = .zero
    ) {
        self.renderer = renderer
        self.viewport = viewport
        self.clip = clip
        self.overdraw = overdraw
    }

    public var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let snap = renderer.snapshot
            let (scale, offset) = waveformCorrection(snapshot: snap, viewWidth: width)

            Renderer(
                waveformData: snap.sampleData,
                displayMode: renderer.displayMode,
                xScale: scale,
                xOffset: offset
            )
            .clipShape(HorizontalOverdrawClip(overdraw: overdraw))
            .onChange(
                of: RenderInputs(
                    viewport: viewport,
                    clip: clip,
                    width: width,
                    overdraw: overdraw,
                    displayMode: renderer.displayMode
                ),
                initial: true
            ) { _, inputs in
                renderer.update(viewport: inputs.viewport, clip: inputs.clip, width: inputs.width, overdraw: inputs.overdraw)
            }
        }
    }

    /// Everything `renderer.update` depends on; any change re-runs it once.
    private struct RenderInputs: Equatable {
        let viewport: TimelineViewport
        let clip: ClipDescriptor
        let width: CGFloat
        let overdraw: HorizontalOverdraw
        let displayMode: WaveformDisplayMode
    }

    /// Computes x scale and offset to map renderer pixels to current viewport screen coords.
    /// Uses the same formula as grid lines: (sample - vp.lower) / vp.count * width.
    /// This ensures waveform and grid positions use identical floating-point operations.
    private func waveformCorrection(snapshot: RenderSnapshot, viewWidth: CGFloat) -> (scale: CGFloat, offset: CGFloat) {
        guard snapshot.sampleData.count > 0, viewport.visibleCount > 0 else {
            return (1, 0)
        }
        let scale = CGFloat(snapshot.samplesPerPixel) * viewWidth / CGFloat(viewport.visibleCount)
        let offset = viewport.screenX(for: snapshot.paddedTimelineStart, viewWidth: viewWidth)
        return (scale, offset)
    }
}
