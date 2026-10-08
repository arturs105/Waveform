import CoreGraphics
import SwiftUI

/// How far past its own frame a waveform may draw on each side, in points.
///
/// The view's frame — and so the viewport mapping, hit-testing and anything
/// aligned to its edges — stays exactly where it is; only the clip widens, so
/// already-rendered samples that fall beyond the frame (the renderer pads
/// 150% of the visible width each side) are drawn there instead of cut off.
/// `.zero` is the default: clip to the frame.
public struct HorizontalOverdraw: Equatable, Sendable {
    public let leading: CGFloat
    public let trailing: CGFloat

    public static let zero = HorizontalOverdraw(leading: 0, trailing: 0)

    /// Negative values clamp to zero: overdraw only ever widens the clip.
    public init(leading: CGFloat, trailing: CGFloat) {
        self.leading = max(0, leading)
        self.trailing = max(0, trailing)
    }

    /// The frame widened by the overdraw on each side; height untouched.
    public func clipRect(in bounds: CGRect) -> CGRect {
        CGRect(
            x: bounds.minX - leading,
            y: bounds.minY,
            width: bounds.width + leading + trailing,
            height: bounds.height
        )
    }

    /// The timeline samples drawn on screen: the viewport's visible range
    /// widened by the overdraw, converted at the viewport's points-per-sample
    /// and rounded outward. May extend past `0..<totalLength`; callers
    /// intersect it with what they draw. `.zero` (or a zero width) = the
    /// visible range unchanged.
    public func drawnRange(of viewport: TimelineViewport, viewWidth: CGFloat) -> Range<Int> {
        let visible = viewport.visibleRange
        guard viewWidth > 0, visible.count > 0 else { return visible }
        let samplesPerPoint = CGFloat(visible.count) / viewWidth
        let before = Int((leading * samplesPerPoint).rounded(.up))
        let after = Int((trailing * samplesPerPoint).rounded(.up))
        return (visible.lowerBound - before)..<(visible.upperBound + after)
    }
}

/// Clip shape for `HorizontalOverdraw`: a rectangle wider than the view it
/// clips, which SwiftUI honours — content outside the frame but inside the
/// shape stays visible.
public struct HorizontalOverdrawClip: Shape {
    let overdraw: HorizontalOverdraw

    public init(overdraw: HorizontalOverdraw) {
        self.overdraw = overdraw
    }

    public func path(in rect: CGRect) -> Path {
        Path(overdraw.clipRect(in: rect))
    }
}
