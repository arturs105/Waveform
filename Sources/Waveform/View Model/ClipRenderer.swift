import AVFoundation
import SwiftUI

/// Atomic snapshot of a completed render — published as a single value
/// so SwiftUI never sees partially-updated state.
public struct RenderSnapshot: Equatable {
    public var sampleData: [SampleData]
    /// Timeline sample position of the first rendered pixel.
    public var paddedTimelineStart: Int
    /// Exact samples-per-pixel (floating point to avoid quantization jitter).
    public var samplesPerPixel: Double

    public static let empty = RenderSnapshot(sampleData: [], paddedTimelineStart: 0, samplesPerPixel: 1)

    /// Compares metadata only (not sample contents) to avoid O(n) array comparisons.
    /// Safe because re-renders always produce different paddedTimelineStart or samplesPerPixel.
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.paddedTimelineStart == rhs.paddedTimelineStart
            && lhs.samplesPerPixel == rhs.samplesPerPixel
            && lhs.sampleData.count == rhs.sampleData.count
    }

    /// Timeline sample just past the last rendered pixel (rounded, so float
    /// error can't leave a render one sample short of its clip's end).
    public var renderedEnd: Int {
        paddedTimelineStart + Int((Double(sampleData.count) * samplesPerPixel).rounded())
    }

    /// Whether this render has samples for every position in `range`.
    /// An empty render covers nothing.
    public func covers(_ range: Range<Int>) -> Bool {
        !sampleData.isEmpty && paddedTimelineStart <= range.lowerBound && renderedEnd >= range.upperBound
    }
}

/// Renders audio for a clip given a viewport. Does not own viewport state.
/// Replaces `WaveformGenerator` — viewport is externally driven.
@MainActor
public class ClipRenderer: ObservableObject {
    /// The loaded audio buffer (nil until loadAsync completes).
    public private(set) var audioBuffer: AVAudioPCMBuffer?
    /// Frame count of the loaded audio.
    public private(set) var audioFrameCount: Int = 0
    /// Sample rate of the loaded audio.
    public private(set) var audioSampleRate: Int = 0

    /// Single atomic snapshot of the latest render output.
    @Published public private(set) var snapshot: RenderSnapshot = .empty

    @Published public var displayMode: WaveformDisplayMode = .normal

    private var loadTask: Task<(AVAudioPCMBuffer, Int, Int), any Error>?
    private var generateTask: GenerateTask?
    private var renderGeneration: Int = 0
    private var lastViewport: TimelineViewport?
    private var lastClip: ClipDescriptor?
    private var lastWidth: CGFloat = 0
    private var lastDisplayMode: WaveformDisplayMode = .normal
    private var lastOverdraw: HorizontalOverdraw = .zero

    public init() {}

    // MARK: - Loading

    /// Loads audio from a URL on a background thread.
    /// Cancels any in-flight load before starting.
    ///
    /// - Parameter isolatingChannel: when set, only that channel is drawn. Use it
    ///   for files whose remaining channels are never played back, so the drawn
    ///   envelope matches what the listener hears. Ignored for mono files and
    ///   out-of-range indices.
    public func loadAsync(url: URL, isolatingChannel: Int? = nil) async throws {
        loadTask?.cancel()
        let task = Task.detached(priority: .userInitiated) {
            let audioFile = try AVAudioFile(forReading: url)
            let capacity = AVAudioFrameCount(audioFile.length)
            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: audioFile.processingFormat,
                frameCapacity: capacity
            ) else {
                throw ClipRendererError.failedToCreateBuffer
            }
            try audioFile.read(into: buffer)
            let drawn = try Self.isolate(channel: isolatingChannel, of: buffer)
            return (drawn, Int(capacity), Int(audioFile.processingFormat.sampleRate))
        }
        loadTask = task
        let (buffer, frameCount, sampleRate) = try await task.value

        guard !Task.isCancelled else { return }
        self.audioBuffer = buffer
        self.audioFrameCount = frameCount
        self.audioSampleRate = sampleRate
    }

    /// Copies a single channel into a fresh mono buffer, so the generator — which
    /// takes the min/max across every channel — can't fold in audio that is never
    /// played. Returns the original buffer when there is nothing to isolate.
    nonisolated static func isolate(channel: Int?, of buffer: AVAudioPCMBuffer) throws -> AVAudioPCMBuffer {
        guard let channel,
              channel >= 0,
              buffer.format.channelCount > 1,
              channel < Int(buffer.format.channelCount),
              let source = buffer.floatChannelData,
              let monoFormat = AVAudioFormat(
                commonFormat: buffer.format.commonFormat,
                sampleRate: buffer.format.sampleRate,
                channels: 1,
                interleaved: false)
        else { return buffer }

        guard let mono = AVAudioPCMBuffer(pcmFormat: monoFormat, frameCapacity: max(buffer.frameLength, 1)),
              let destination = mono.floatChannelData else {
            throw ClipRendererError.failedToCreateBuffer
        }
        mono.frameLength = buffer.frameLength
        // Deinterleaved (what `AVAudioFile` hands back): one pointer per channel,
        // stride 1. Interleaved: a single pointer with the channels woven
        // together, so `floatChannelData[channel]` would run off the end.
        let stride = buffer.stride
        let samples = buffer.format.isInterleaved ? source[0] : source[channel]
        let offset = buffer.format.isInterleaved ? channel : 0
        for frame in 0..<Int(buffer.frameLength) {
            destination[0][frame] = samples[frame * stride + offset]
        }
        return mono
    }

    public var isLoaded: Bool { audioBuffer != nil }

    /// Cancels any in-flight render task.
    public func cancelRender() {
        generateTask?.cancel()
    }

    // MARK: - Rendering

    /// Updates the render for the given viewport and clip descriptor.
    /// Call whenever viewport, clip, view width or overdraw changes.
    /// `overdraw` widens what counts as on screen (see `HorizontalOverdraw`):
    /// a clip drawn only in the strips still renders, and the existing render
    /// must cover out to the strips' outer edges.
    public func update(
        viewport: TimelineViewport,
        clip: ClipDescriptor,
        width: CGFloat,
        overdraw: HorizontalOverdraw = .zero
    ) {
        guard width > 0, let audioBuffer else { return }

        // Skip if nothing changed
        if viewport == lastViewport && clip == lastClip && width == lastWidth
            && displayMode == lastDisplayMode && overdraw == lastOverdraw {
            return
        }

        let clipChanged = clip != lastClip
        let displayModeChanged = displayMode != lastDisplayMode
        let widthChanged = width != lastWidth

        lastViewport = viewport
        lastClip = clip
        lastWidth = width
        lastDisplayMode = displayMode
        lastOverdraw = overdraw

        // Intersect clip's timeline range with what's drawn on screen
        let clipRange = clip.timelineRange
        let visibleRange = viewport.visibleRange
        let drawnRange = overdraw.drawnRange(of: viewport, viewWidth: width)

        guard clipRange.overlaps(drawnRange) else {
            // Clip not visible — clear
            generateTask?.cancel()
            snapshot = .empty
            return
        }

        // Check if the existing render still covers the drawn range with adequate resolution.
        // If so, skip re-rendering — the correction transform handles viewport changes smoothly.
        // Clamped to the clip: nothing exists past its ends, and an overdraw strip
        // reaching before the timeline start (pan 0) would otherwise never count
        // as covered.
        if !clipChanged && !displayModeChanged && !widthChanged && snapshot.sampleData.count > 0 {
            let snap = snapshot
            let drawnCovered = snap.covers(drawnRange.clamped(to: clipRange))

            // Check zoom: current ideal spp vs rendered spp
            let idealSpp = Double(visibleRange.count) / Double(width)
            let zoomRatio = snap.samplesPerPixel / idealSpp
            // Re-render if zoom changed by >2x in either direction, or if panned beyond buffer
            let zoomOk = zoomRatio > 0.5 && zoomRatio < 2.0

            if drawnCovered && zoomOk {
                return
            }
        }

        generateTask?.cancel()

        guard let renderRange = clipRenderRange(clip: clip, viewport: viewport, viewWidth: width, overdraw: overdraw) else {
            snapshot = .empty
            return
        }

        renderGeneration += 1
        let expectedGeneration = renderGeneration

        let task = GenerateTask(audioBuffer: audioBuffer)
        generateTask = task

        task.resume(
            width: CGFloat(renderRange.pixelWidth),
            audioRange: renderRange.audioRange,
            displayMode: displayMode
        ) { [weak self] data in
            Task { @MainActor [weak self] in
                guard let self, self.renderGeneration == expectedGeneration else { return }
                self.snapshot = RenderSnapshot(
                    sampleData: data,
                    paddedTimelineStart: renderRange.paddedTimelineStart,
                    samplesPerPixel: renderRange.samplesPerPixel
                )
            }
        }
    }

    public enum ClipRendererError: Error {
        case failedToCreateBuffer
    }
}
