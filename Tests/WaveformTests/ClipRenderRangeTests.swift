import Testing
@testable import Waveform

@Suite("ClipRenderRange Tests")
struct ClipRenderRangeTests {

    // MARK: - Visibility

    @Test("returns nil when clip is not visible")
    func clipNotVisible() {
        let clip = ClipDescriptor(nativePrepend: 10000, audioFrameCount: 5000, sampleRate: 44100, timelineRate: 44100)
        let viewport = TimelineViewport(visibleRange: 0..<5000, totalLength: 20000)
        let result = clipRenderRange(clip: clip, viewport: viewport, viewWidth: 500)
        #expect(result == nil)
    }

    @Test("returns nil when viewWidth is zero")
    func zeroViewWidth() {
        let clip = ClipDescriptor(nativePrepend: 0, audioFrameCount: 5000, sampleRate: 44100, timelineRate: 44100)
        let viewport = TimelineViewport(visibleRange: 0..<5000, totalLength: 10000)
        let result = clipRenderRange(clip: clip, viewport: viewport, viewWidth: 0)
        #expect(result == nil)
    }

    @Test("returns non-nil when clip is fully visible")
    func clipFullyVisible() {
        let clip = ClipDescriptor(nativePrepend: 1000, audioFrameCount: 2000, sampleRate: 44100, timelineRate: 44100)
        let viewport = TimelineViewport(visibleRange: 0..<10000, totalLength: 10000)
        let result = clipRenderRange(clip: clip, viewport: viewport, viewWidth: 500)
        #expect(result != nil)
    }

    @Test("returns non-nil when clip partially overlaps visible range")
    func clipPartialOverlap() {
        // Clip starts at 3000, visible range is 0..<5000
        let clip = ClipDescriptor(nativePrepend: 3000, audioFrameCount: 4000, sampleRate: 44100, timelineRate: 44100)
        let viewport = TimelineViewport(visibleRange: 0..<5000, totalLength: 10000)
        let result = clipRenderRange(clip: clip, viewport: viewport, viewWidth: 500)
        #expect(result != nil)
    }

    // MARK: - Audio range mapping

    @Test("audio range starts at inPoint offset from clip start")
    func audioRangeWithInPoint() {
        let clip = ClipDescriptor(
            nativePrepend: 0,
            inPoint: 100,
            audioFrameCount: 5000,
            sampleRate: 44100,
            timelineRate: 44100
        )
        let viewport = TimelineViewport(visibleRange: 0..<1000, totalLength: 5000)
        let result = clipRenderRange(clip: clip, viewport: viewport, viewWidth: 200)
        #expect(result != nil)
        // Audio range lower bound should be >= inPoint (100)
        #expect(result!.audioRange.lowerBound >= 100)
    }

    @Test("audio range stays within clip audio frame count")
    func audioRangeClamped() {
        let clip = ClipDescriptor(nativePrepend: 0, audioFrameCount: 1000, sampleRate: 44100, timelineRate: 44100)
        let viewport = TimelineViewport(visibleRange: 0..<2000, totalLength: 5000)
        let result = clipRenderRange(clip: clip, viewport: viewport, viewWidth: 500)
        #expect(result != nil)
        #expect(result!.audioRange.upperBound <= 1000)
    }

    @Test("returns nil when audio range is empty after clamping")
    func emptyAudioRange() {
        // Clip positioned at 5000, but only 0 frames
        let clip = ClipDescriptor(nativePrepend: 5000, audioFrameCount: 0, sampleRate: 44100, timelineRate: 44100)
        let viewport = TimelineViewport(visibleRange: 4000..<6000, totalLength: 10000)
        let result = clipRenderRange(clip: clip, viewport: viewport, viewWidth: 500)
        #expect(result == nil)
    }

    // MARK: - Padding

    @Test("padded start is clamped to clip lower bound")
    func paddedStartClampedToClip() {
        // Clip starts at 100, visible range is 0..<5000 — padding would push start negative
        let clip = ClipDescriptor(nativePrepend: 100, audioFrameCount: 44100, sampleRate: 44100, timelineRate: 44100)
        let viewport = TimelineViewport(visibleRange: 0..<5000, totalLength: 50000)
        let result = clipRenderRange(clip: clip, viewport: viewport, viewWidth: 500)
        #expect(result != nil)
        #expect(result!.paddedTimelineStart >= clip.timelinePosition)
    }

    @Test("padded end is clamped to clip upper bound")
    func paddedEndClampedToClip() {
        let clip = ClipDescriptor(nativePrepend: 0, audioFrameCount: 1000, sampleRate: 44100, timelineRate: 44100)
        let viewport = TimelineViewport(visibleRange: 0..<1000, totalLength: 10000)
        let result = clipRenderRange(clip: clip, viewport: viewport, viewWidth: 500)
        #expect(result != nil)
        #expect(result!.audioRange.upperBound <= clip.audioFrameCount)
    }

    // MARK: - Pixel width and spp

    @Test("samplesPerPixel matches timeline span over pixel width")
    func samplesPerPixelConsistency() {
        let clip = ClipDescriptor(nativePrepend: 0, audioFrameCount: 44100, sampleRate: 44100, timelineRate: 44100)
        let viewport = TimelineViewport(visibleRange: 0..<44100, totalLength: 44100)
        let result = clipRenderRange(clip: clip, viewport: viewport, viewWidth: 300)
        #expect(result != nil)
        // At equal rates the timeline span equals the native audio range count.
        let expected = Double(result!.audioRange.count) / Double(result!.pixelWidth)
        #expect(abs(result!.samplesPerPixel - expected) < 0.001)
    }

    @Test("pixelWidth is at least 1")
    func pixelWidthAtLeastOne() {
        let clip = ClipDescriptor(nativePrepend: 0, audioFrameCount: 100, sampleRate: 44100, timelineRate: 44100)
        let viewport = TimelineViewport(visibleRange: 0..<44100 * 100, totalLength: 44100 * 100)
        let result = clipRenderRange(clip: clip, viewport: viewport, viewWidth: 500)
        #expect(result != nil)
        #expect(result!.pixelWidth >= 1)
    }

    // MARK: - Mixed sample rates

    @Test("lower-rate clip maps timeline coords back into native audio range")
    func mixedRateAudioRangeStaysNative() {
        // 1s of 44.1 kHz audio displayed on a 48 kHz timeline.
        let clip = ClipDescriptor(nativePrepend: 0, audioFrameCount: 44100, sampleRate: 44100, timelineRate: 48000)
        // Clip occupies 48000 timeline samples; view the whole thing.
        let viewport = TimelineViewport(visibleRange: 0..<48000, totalLength: 48000)
        let result = clipRenderRange(clip: clip, viewport: viewport, viewWidth: 480)
        #expect(result != nil)
        // audioRange indexes the native buffer, so it must never exceed the native frame count.
        #expect(result!.audioRange.upperBound <= 44100)
        // samplesPerPixel is a timeline-domain measure (span 48000 over 480 px ≈ 100).
        let expected = Double(result!.paddedTimelineStart.distance(to: clip.timelineEndPosition)) / Double(result!.pixelWidth)
        #expect(abs(result!.samplesPerPixel - expected) < 1.0)
    }
}
