import Testing
import AVFoundation
@testable import Waveform

@Suite("TransientAnalyzer Tests")
struct TransientAnalyzerTests {

    private static let sampleRate: Double = 48000

    /// Builds a buffer with sharp decaying hits at the given seconds.
    private func buffer(hitsAt seconds: [Double], duration: Double = 4) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: Self.sampleRate, channels: 1)!
        let frameCount = AVAudioFrameCount(duration * Self.sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let data = buffer.floatChannelData![0]
        for frame in 0..<Int(frameCount) {
            // Quiet noise floor so the detector isn't working against pure silence.
            data[frame] = 0.002 * sinf(Float(frame) / 30)
        }
        for second in seconds {
            let start = Int(second * Self.sampleRate)
            let length = Int(0.25 * Self.sampleRate)
            for offset in 0..<length where start + offset < Int(frameCount) {
                let decay = expf(-Float(offset) / Float(Self.sampleRate * 0.03))
                data[start + offset] += 0.9 * decay * sinf(Float(offset) / 4)
            }
        }
        return buffer
    }

    @Test("Finds one onset per hit, at the hit")
    func findsHits() {
        let hits = [0.5, 1.25, 2.0, 3.1]
        let onsets = TransientAnalyzer.onsetSamples(in: buffer(hitsAt: hits), adaptive: true)

        #expect(onsets.count == hits.count)
        for (onset, hit) in zip(onsets, hits) {
            let seconds = Double(onset) / Self.sampleRate
            // Within one analysis column of the true attack.
            #expect(abs(seconds - hit) <= TransientAnalyzer.hopSeconds * 2)
        }
    }

    @Test("Onsets are frame positions, so they don't depend on any viewport")
    func independentOfViewport() {
        let audio = buffer(hitsAt: [0.5, 1.25])
        let first = TransientAnalyzer.onsetSamples(in: audio, adaptive: true)
        let second = TransientAnalyzer.onsetSamples(in: audio, adaptive: true)

        #expect(first == second)
        #expect(!first.isEmpty)
    }

    @Test("Silence yields no onsets")
    func silence() {
        let format = AVAudioFormat(standardFormatWithSampleRate: Self.sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 48000)!
        buffer.frameLength = 48000

        #expect(TransientAnalyzer.onsetSamples(in: buffer, adaptive: true).isEmpty)
    }
}

@Suite("TransientMarkers projection")
struct TransientMarkerProjectionTests {

    /// The x a marker is drawn at, mirroring `TransientMarkers.body`.
    private func screenX(sample: Int, clip: ClipDescriptor, viewport: TimelineViewport, width: CGFloat) -> CGFloat {
        let timelineSample = clip.timelinePosition + clip.toTimeline(sample - clip.inPoint)
        return viewport.screenX(for: timelineSample, viewWidth: width)
    }

    @Test("A marker keeps its audio position across zoom levels")
    func stableAcrossZoom() {
        let clip = ClipDescriptor(
            nativePrepend: 44100,
            audioFrameCount: 44100 * 10,
            sampleRate: 44100,
            timelineRate: 44100
        )
        let onset = 44100 * 2  // two seconds into the audio
        let width: CGFloat = 300

        let wide = TimelineViewport(totalLength: 44100 * 20)
        let zoomed = wide.zoomed(by: 4)

        // Same timeline sample under both viewports — only the screen x differs.
        let wideX = screenX(sample: onset, clip: clip, viewport: wide, width: width)
        let zoomedX = screenX(sample: onset, clip: clip, viewport: zoomed, width: width)
        let wideSample = wide.timelineSample(for: wideX, viewWidth: width)
        let zoomedSample = zoomed.timelineSample(for: zoomedX, viewWidth: width)

        #expect(abs(wideSample - zoomedSample) <= wide.visibleCount / Int(width) + 1)
    }
}
