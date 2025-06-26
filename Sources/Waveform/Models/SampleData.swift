public struct SampleData: Equatable {
    var min: Float
    var max: Float
    
    static var zero: SampleData {
        SampleData(min: 0, max: 0)
    }
}
