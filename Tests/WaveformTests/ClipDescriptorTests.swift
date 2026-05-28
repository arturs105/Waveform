import Testing
@testable import Waveform

@Suite("ClipDescriptor Tests")
struct ClipDescriptorTests {

    // MARK: - Equal-rate identity

    @Test("timeline geometry equals native values when rates match")
    func equalRateIsIdentity() {
        let clip = ClipDescriptor(
            nativePrepend: 12345,
            inPoint: 100,
            audioFrameCount: 50000,
            sampleRate: 48000,
            timelineRate: 48000
        )
        #expect(clip.rateScale == 1)
        #expect(clip.timelinePosition == 12345)
        #expect(clip.timelineDuration == 50000 - 100)
        #expect(clip.timelineEndPosition == 12345 + (50000 - 100))
    }

    // MARK: - Rate scaling

    @Test("lower-rate clip scales up into the timeline domain")
    func lowerRateScalesUp() {
        // 1s prepend + 1s of audio at 44.1 kHz, displayed on a 48 kHz timeline.
        let clip = ClipDescriptor(
            nativePrepend: 44100,
            audioFrameCount: 44100,
            sampleRate: 44100,
            timelineRate: 48000
        )
        // 1 second in either domain maps to that domain's sample count.
        #expect(clip.timelinePosition == 48000)
        #expect(clip.timelineDuration == 48000)
        #expect(clip.timelineEndPosition == 96000)
    }

    // MARK: - Alignment across rates (the bug this fixes)

    @Test("clips with equal wall-clock start and duration align regardless of native rate")
    func mixedRatesAlignByTime() {
        // Both clips: 0.5s lead-in, then 2s of audio. One captured at 48 kHz, one at 44.1 kHz.
        let timelineRate = 48000
        let clip48 = ClipDescriptor(
            nativePrepend: 24000,        // 0.5s @ 48k
            audioFrameCount: 96000,      // 2s @ 48k
            sampleRate: 48000,
            timelineRate: timelineRate
        )
        let clip44 = ClipDescriptor(
            nativePrepend: 22050,        // 0.5s @ 44.1k
            audioFrameCount: 88200,      // 2s @ 44.1k
            sampleRate: 44100,
            timelineRate: timelineRate
        )
        // Same physical instants must land on the same timeline coordinates (±1 for rounding).
        #expect(abs(clip48.timelinePosition - clip44.timelinePosition) <= 1)
        #expect(abs(clip48.timelineEndPosition - clip44.timelineEndPosition) <= 1)
    }

    // MARK: - Conversion helpers

    @Test("toNative inverts toTimeline within rounding tolerance")
    func conversionRoundTrips() {
        let clip = ClipDescriptor(
            nativePrepend: 0,
            audioFrameCount: 100000,
            sampleRate: 44100,
            timelineRate: 48000
        )
        for native in [0, 1, 441, 44100, 88200, 99999] {
            let roundTripped = clip.toNative(clip.toTimeline(native))
            #expect(abs(roundTripped - native) <= 1)
        }
    }

    @Test("rateScale falls back to 1 for a zero sample rate")
    func zeroSampleRateIsSafe() {
        let clip = ClipDescriptor(
            nativePrepend: 500,
            audioFrameCount: 1000,
            sampleRate: 0,
            timelineRate: 48000
        )
        #expect(clip.rateScale == 1)
        #expect(clip.timelinePosition == 500)
        #expect(clip.timelineDuration == 1000)
    }
}
