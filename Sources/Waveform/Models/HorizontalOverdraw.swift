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
