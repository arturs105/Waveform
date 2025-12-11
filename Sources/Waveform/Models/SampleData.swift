public struct SampleData: Equatable {
    public var min: Float
    public var max: Float
    
    public static var zero: SampleData {
        SampleData(min: 0, max: 0)
    }
}
