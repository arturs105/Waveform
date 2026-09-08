import AVFoundation
import Accelerate

/// Reduces a span of audio frames to one waveform column.
enum ColumnReducer {
    /// Min/max/RMS across all channels of `length` frames starting at `start`.
    static func reduce(
        floatChannelData: UnsafePointer<UnsafeMutablePointer<Float>>,
        channels: Int,
        stride: vDSP_Stride,
        start: Int,
        length: Int
    ) -> SampleData {
        var data: SampleData = .zero
        for channel in 0..<channels {
            let pointer = floatChannelData[channel].advanced(by: start)
            let len = vDSP_Length(length)

            var value: Float = 0
            vDSP_minv(pointer, stride, &value, len)
            data.min = min(value, data.min)

            vDSP_maxv(pointer, stride, &value, len)
            data.max = max(value, data.max)

            vDSP_rmsqv(pointer, stride, &value, len)
            data.rms = max(value, data.rms)
        }
        return data
    }
}
