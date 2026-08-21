import Testing
import AVFoundation
@testable import Waveform

/// Some files keep channels that are never played back (a directional capture may
/// store a reference channel alongside the audible beam). The drawn envelope has
/// to match what is heard, so the renderer can be told to draw one channel only.
@Suite("ClipRenderer channel isolation")
@MainActor
struct ClipRendererChannelTests {

    /// Channel 0 at 0.2, channel 1 deliberately 4x louder so "isolated" and
    /// "all channels" produce visibly different envelopes.
    private func lopsidedStereo(frames: AVAudioFrameCount = 512) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        for frame in 0..<Int(frames) {
            buffer.floatChannelData![0][frame] = 0.2
            buffer.floatChannelData![1][frame] = 0.8
        }
        return buffer
    }

    @Test("isolating a channel yields a mono buffer carrying that channel")
    func isolatesRequestedChannel() throws {
        let isolated = try ClipRenderer.isolate(channel: 0, of: lopsidedStereo())
        #expect(isolated.format.channelCount == 1)
        #expect(isolated.frameLength == 512)
        #expect(abs(isolated.floatChannelData![0][0] - 0.2) < 0.0001)
        #expect(abs(isolated.floatChannelData![0][511] - 0.2) < 0.0001)
    }

    @Test("no channel requested leaves the buffer untouched")
    func keepsEveryChannelByDefault() throws {
        let source = lopsidedStereo()
        let result = try ClipRenderer.isolate(channel: nil, of: source)
        #expect(result === source)
    }

    @Test("out-of-range or mono input is left untouched")
    func ignoresImpossibleRequests() throws {
        let source = lopsidedStereo()
        #expect(try ClipRenderer.isolate(channel: 5, of: source) === source)

        let monoFormat = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1)!
        let mono = AVAudioPCMBuffer(pcmFormat: monoFormat, frameCapacity: 16)!
        mono.frameLength = 16
        #expect(try ClipRenderer.isolate(channel: 0, of: mono) === mono)
    }

    @Test("the drawn envelope follows the isolated channel, not the loud one")
    func generatorSeesOnlyIsolatedChannel() async throws {
        let isolated = try ClipRenderer.isolate(channel: 0, of: lopsidedStereo())
        let task = GenerateTask(audioBuffer: isolated)

        let samples: [SampleData] = await withCheckedContinuation { continuation in
            task.resume(width: 4, audioRange: 0..<512) { continuation.resume(returning: $0) }
        }

        #expect(samples.count == 4)
        // 0.2 = the kept channel. 0.8 would mean the discarded channel leaked in.
        for sample in samples {
            #expect(abs(sample.max - 0.2) < 0.01)
        }
    }
}
