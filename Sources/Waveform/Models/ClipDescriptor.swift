import Foundation

/// Describes a clip's position and extent in the timeline.
///
/// A clip's audio is in its own *native* `sampleRate`, but several clips at
/// different rates share one timeline. Timeline-coordinate geometry below is
/// expressed in `timelineRate` samples (the canonical rate of the shared
/// timeline — conventionally the max of the session's track rates), so clips at
/// 44.1 kHz and 48 kHz line up by wall-clock time. Audio-domain values
/// (`inPoint`, `audioFrameCount`) stay in native samples for buffer indexing.
public struct ClipDescriptor: Equatable, Sendable {
    /// Lead-in silence before the clip, in *native* samples (maps from samplesToPrepend).
    public var nativePrepend: Int
    /// Trim start within the audio file, in native samples (future: trimming support).
    public var inPoint: Int
    /// Total frames in the audio file (native rate).
    public var audioFrameCount: Int
    /// Native sample rate of the audio file.
    public var sampleRate: Int
    /// Canonical rate of the shared timeline. Native quantities are scaled by
    /// `timelineRate / sampleRate` to produce timeline coordinates.
    public var timelineRate: Int

    public init(
        nativePrepend: Int,
        inPoint: Int = 0,
        audioFrameCount: Int,
        sampleRate: Int,
        timelineRate: Int
    ) {
        self.nativePrepend = nativePrepend
        self.inPoint = inPoint
        self.audioFrameCount = audioFrameCount
        self.sampleRate = sampleRate
        self.timelineRate = timelineRate
    }

    /// Timeline:native sample ratio. 1.0 when the clip is already at the timeline rate.
    public var rateScale: Double {
        guard sampleRate > 0 else { return 1 }
        return Double(timelineRate) / Double(sampleRate)
    }

    /// Converts a native sample count to timeline samples.
    public func toTimeline(_ native: Int) -> Int {
        Int((Double(native) * rateScale).rounded())
    }

    /// Converts a timeline sample count to native samples.
    public func toNative(_ timeline: Int) -> Int {
        Int((Double(timeline) / rateScale).rounded())
    }

    /// Start sample in timeline coordinates.
    public var timelinePosition: Int {
        toTimeline(nativePrepend)
    }

    /// Duration of the clip in timeline samples (from inPoint to end).
    public var timelineDuration: Int {
        toTimeline(max(0, audioFrameCount - inPoint))
    }

    /// End position in timeline coordinates.
    public var timelineEndPosition: Int {
        timelinePosition + timelineDuration
    }

    /// The range this clip occupies in timeline coordinates.
    public var timelineRange: Range<Int> {
        timelinePosition..<timelineEndPosition
    }

}
