import SwiftUI

/// Vertical ticks at a clip's onsets.
///
/// Positions come from the clip-wide analysis in native audio frames and are
/// projected through the viewport at draw time, so a mark stays on the same
/// beat no matter how far you zoom.
struct TransientMarkers: View {
    let onsetSamples: [Int]
    let clip: ClipDescriptor
    let viewport: TimelineViewport

    /// Closest two marks may be drawn before one is dropped — keeps a zoomed-out
    /// view from turning into a solid wash.
    private static let minimumSpacing: CGFloat = 2

    var body: some View {
        Canvas { context, size in
            var lastX: CGFloat = -.greatestFiniteMagnitude
            for sample in onsetSamples {
                let timelineSample = clip.timelinePosition + clip.toTimeline(sample - clip.inPoint)
                guard viewport.visibleRange.contains(timelineSample) else { continue }
                let x = viewport.screenX(for: timelineSample, viewWidth: size.width)
                guard x - lastX >= Self.minimumSpacing else { continue }
                lastX = x
                context.fill(
                    Path(CGRect(x: x, y: 0, width: 1, height: size.height)),
                    with: .color(.primary.opacity(0.55))
                )
            }
        }
        .allowsHitTesting(false)
    }
}
