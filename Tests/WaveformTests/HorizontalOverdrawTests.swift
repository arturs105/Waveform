import Testing
import CoreGraphics
@testable import Waveform

@Suite("HorizontalOverdraw")
struct HorizontalOverdrawTests {
    let bounds = CGRect(x: 0, y: 0, width: 300, height: 80)

    @Test("zero overdraw clips exactly to bounds")
    func zeroClipsToBounds() {
        #expect(HorizontalOverdraw.zero.clipRect(in: bounds) == bounds)
    }

    @Test("leading overdraw extends the clip before the origin, height untouched")
    func leadingExtends() {
        let rect = HorizontalOverdraw(leading: 64, trailing: 0).clipRect(in: bounds)
        #expect(rect == CGRect(x: -64, y: 0, width: 364, height: 80))
    }

    @Test("trailing overdraw extends the clip past the far edge")
    func trailingExtends() {
        let rect = HorizontalOverdraw(leading: 0, trailing: 47).clipRect(in: bounds)
        #expect(rect == CGRect(x: 0, y: 0, width: 347, height: 80))
    }

    @Test("both sides at once")
    func bothSides() {
        let rect = HorizontalOverdraw(leading: 10, trailing: 20).clipRect(in: bounds)
        #expect(rect == CGRect(x: -10, y: 0, width: 330, height: 80))
    }

    @Test("negative values clamp to zero — overdraw never shrinks the clip")
    func negativeClampsToZero() {
        let overdraw = HorizontalOverdraw(leading: -5, trailing: -9)
        #expect(overdraw == .zero)
        #expect(overdraw.clipRect(in: bounds) == bounds)
    }

    // MARK: - drawnRange

    // 300pt showing 3000 samples = 10 samples per point.
    let viewport = TimelineViewport(visibleRange: 10_000..<13_000, totalLength: 100_000)

    @Test("zero overdraw: drawn range is the visible range")
    func drawnRangeZero() {
        #expect(HorizontalOverdraw.zero.drawnRange(of: viewport, viewWidth: 300) == 10_000..<13_000)
    }

    @Test("drawn range widens by each strip at the viewport's samples per point")
    func drawnRangeWidens() {
        let range = HorizontalOverdraw(leading: 64, trailing: 47).drawnRange(of: viewport, viewWidth: 300)
        #expect(range == 9_360..<13_470)
    }

    @Test("fractional samples round outward")
    func drawnRangeRoundsOutward() {
        let range = HorizontalOverdraw(leading: 0.05, trailing: 0.05).drawnRange(of: viewport, viewWidth: 300)
        #expect(range == 9_999..<13_001)
    }

    @Test("may extend before the timeline start")
    func drawnRangeBeforeStart() {
        let atStart = TimelineViewport(visibleRange: 0..<3000, totalLength: 100_000)
        #expect(HorizontalOverdraw(leading: 10, trailing: 0).drawnRange(of: atStart, viewWidth: 300) == -100..<3000)
    }

    @Test("zero width: visible range unchanged")
    func drawnRangeZeroWidth() {
        #expect(HorizontalOverdraw(leading: 64, trailing: 47).drawnRange(of: viewport, viewWidth: 0) == 10_000..<13_000)
    }
}
