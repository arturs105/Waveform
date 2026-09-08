import AVFoundation
import Accelerate

/// Finds onsets in a whole clip at a fixed time resolution.
///
/// Deliberately independent of the viewport: detecting on the columns of the
/// current render would re-derive different onsets at every zoom level, so the
/// marks would crawl as you zoom. Analysing once per clip at a musically
/// sensible resolution (`hopSeconds`) pins each mark to an audio frame, and
/// zooming only changes where that frame lands on screen.
enum TransientAnalyzer {
    /// Analysis column length. 5 ms resolves drum hits without splitting one
    /// attack across several columns.
    static let hopSeconds: Double = 0.005
    /// Minimum gap between two onsets — one attack yields one mark.
    static let minimumOnsetSpacingSeconds: Double = 0.05
    /// Fraction of an attack's peak that counts as the start of the attack.
    static let attackThresholdFraction: Float = 0.25

    /// Onset positions in native audio frames.
    /// - Parameters:
    ///   - buffer: The clip's decoded audio.
    ///   - adaptive: Selects the adaptive detector over the legacy one.
    static func onsetSamples(in buffer: AVAudioPCMBuffer, adaptive: Bool) -> [Int] {
        let frameLength = Int(buffer.frameLength)
        let sampleRate = buffer.format.sampleRate
        guard frameLength > 0, sampleRate > 0, let floatChannelData = buffer.floatChannelData else {
            return []
        }

        let hop = max(1, Int(hopSeconds * sampleRate))
        let columnCount = frameLength / hop
        guard columnCount > 1 else { return [] }

        let channels = Int(buffer.format.channelCount)
        let stride = vDSP_Stride(buffer.stride)
        var columns = [SampleData](repeating: .zero, count: columnCount)
        columns.withUnsafeMutableBufferPointer { out in
            DispatchQueue.concurrentPerform(iterations: columnCount) { index in
                out[index] = ColumnReducer.reduce(
                    floatChannelData: floatChannelData,
                    channels: channels,
                    stride: stride,
                    start: index * hop,
                    length: hop
                )
            }
        }

        TransientDetector.computeWeights(&columns, adaptive: adaptive)

        let spacing = max(1, Int(minimumOnsetSpacingSeconds / hopSeconds))
        return TransientDetector.onsetIndices(in: columns, minimumSpacing: spacing).map { column in
            attackFrame(
                column: column,
                hop: hop,
                frameLength: frameLength,
                floatChannelData: floatChannelData,
                channels: channels
            )
        }
    }

    /// Refines a column index to the frame where the attack actually starts —
    /// the first frame in the column (and the one before it, since a rise is
    /// often detected one column late) that reaches a fraction of its peak.
    private static func attackFrame(
        column: Int,
        hop: Int,
        frameLength: Int,
        floatChannelData: UnsafePointer<UnsafeMutablePointer<Float>>,
        channels: Int
    ) -> Int {
        let start = max(0, (column - 1) * hop)
        let end = min(frameLength, (column + 1) * hop)
        guard end > start else { return min(column * hop, frameLength - 1) }

        var peak: Float = 0
        for frame in start..<end {
            var magnitude: Float = 0
            for channel in 0..<channels {
                magnitude = max(magnitude, abs(floatChannelData[channel][frame]))
            }
            peak = max(peak, magnitude)
        }
        guard peak > 0 else { return start }

        let threshold = peak * attackThresholdFraction
        for frame in start..<end {
            for channel in 0..<channels where abs(floatChannelData[channel][frame]) >= threshold {
                return frame
            }
        }
        return start
    }
}
