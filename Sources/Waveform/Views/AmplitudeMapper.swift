import Foundation

/// Maps a raw sample amplitude to the value drawn on screen.
enum AmplitudeMapper {
    /// Applies the amplitude-affecting parts of a style, in draw order.
    static func map(_ amplitude: Float, weight: Float, style: WaveformStyle) -> Float {
        var value = amplitude
        if style.legacyTransientScaling {
            value = TransientScaler.scaleAmplitude(value, weight: weight)
        }
        if style.decibelScale {
            value = decibel(value)
        }
        return value
    }

    /// Maps amplitude to a dB-proportional height: 0 dB → full scale,
    /// `WaveformStyle.decibelFloor` and below → zero. Sign is preserved.
    static func decibel(_ amplitude: Float) -> Float {
        let magnitude = abs(amplitude)
        guard magnitude > 0 else { return 0 }
        let decibels = 20 * log10(magnitude)
        guard decibels > WaveformStyle.decibelFloor else { return 0 }
        let normalized = 1 - decibels / WaveformStyle.decibelFloor
        return amplitude >= 0 ? normalized : -normalized
    }
}
