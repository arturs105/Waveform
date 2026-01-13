public struct SampleData: Equatable, Sendable {
    public var min: Float
    public var max: Float
    public var transientWeight: Float

    public init(min: Float, max: Float, transientWeight: Float = 0) {
        self.min = min
        self.max = max
        self.transientWeight = transientWeight
    }

    public static var zero: SampleData {
        SampleData(min: 0, max: 0, transientWeight: 0)
    }
}
