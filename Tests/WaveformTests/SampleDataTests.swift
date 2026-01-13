import Testing
@testable import Waveform

@Suite("SampleData Tests")
struct SampleDataTests {

    @Test("Zero sample has all zero values")
    func zeroSample() {
        let sample = SampleData.zero
        #expect(sample.min == 0)
        #expect(sample.max == 0)
        #expect(sample.transientWeight == 0)
    }

    @Test("Default transient weight is zero")
    func defaultTransientWeight() {
        let sample = SampleData(min: -0.5, max: 0.8)
        #expect(sample.transientWeight == 0)
    }

    @Test("Custom transient weight is preserved")
    func customTransientWeight() {
        let sample = SampleData(min: -0.3, max: 0.7, transientWeight: 0.85)
        #expect(sample.min == -0.3)
        #expect(sample.max == 0.7)
        #expect(sample.transientWeight == 0.85)
    }

    @Test("Equatable works correctly")
    func equatable() {
        let sample1 = SampleData(min: -0.5, max: 0.5, transientWeight: 0.3)
        let sample2 = SampleData(min: -0.5, max: 0.5, transientWeight: 0.3)
        let sample3 = SampleData(min: -0.5, max: 0.5, transientWeight: 0.4)

        #expect(sample1 == sample2)
        #expect(sample1 != sample3)
    }
}
