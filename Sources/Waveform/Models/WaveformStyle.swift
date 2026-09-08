/// Independently toggleable waveform-drawing features.
///
/// Every flag is separate so the debug panel can A/B each one against the plain
/// peak envelope — the shipping default (`.normal` plus `legacyTransientScaling`
/// driven by the "peaks" toolbar toggle) reproduces the original drawing exactly.
public struct WaveformStyle: Equatable, Sendable {
    /// Use the adaptive onset detector (half-wave rectified, dB-domain,
    /// locally normalised) instead of the original global-max amplitude derivative.
    public var adaptiveDetector: Bool
    /// Draw vertical tick marks at detected onsets. Onsets are analysed once per
    /// clip at a fixed time resolution, so the marks stay put while zooming.
    public var transientMarkers: Bool
    /// Map amplitude through a dB curve (floor `decibelFloor`) instead of linear,
    /// lifting quiet detail into view.
    public var decibelScale: Bool
    /// Stroke the peak envelope with a crisp 1pt outline.
    public var peakOutline: Bool
    /// Original transient mode: attenuates non-transients and power-expands
    /// transients. Misrepresents levels — kept only for comparison.
    public var legacyTransientScaling: Bool

    /// dB value mapped to zero height by `decibelScale`.
    public static let decibelFloor: Float = -40

    public static let normal = WaveformStyle()

    public init(
        adaptiveDetector: Bool = false,
        transientMarkers: Bool = false,
        decibelScale: Bool = false,
        peakOutline: Bool = false,
        legacyTransientScaling: Bool = false
    ) {
        self.adaptiveDetector = adaptiveDetector
        self.transientMarkers = transientMarkers
        self.decibelScale = decibelScale
        self.peakOutline = peakOutline
        self.legacyTransientScaling = legacyTransientScaling
    }

    /// Whether any enabled feature consumes the per-render `SampleData.transientWeight`.
    /// Markers don't — they come from the fixed-resolution clip analysis instead.
    public var needsTransientWeights: Bool {
        legacyTransientScaling
    }
}
