public struct SampleData: Equatable, Sendable {
    public var min: Float
    public var max: Float
    public var transientWeight: Float
    /// Root-mean-square level of the column — the "body" of the signal, drawn
    /// inside the peak envelope so transients stand out as spikes above it.
    public var rms: Float

    public init(min: Float, max: Float, transientWeight: Float = 0, rms: Float = 0) {
        self.min = min
        self.max = max
        self.transientWeight = transientWeight
        self.rms = rms
    }

    public static var zero: SampleData {
        SampleData(min: 0, max: 0, transientWeight: 0, rms: 0)
    }
}
