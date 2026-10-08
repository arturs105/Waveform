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
}
