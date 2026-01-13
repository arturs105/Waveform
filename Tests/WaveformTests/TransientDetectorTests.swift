import Testing
@testable import Waveform

@Suite("TransientDetector Tests")
struct TransientDetectorTests {

    @Test("Empty array unchanged")
    func emptyArray() {
        var samples: [SampleData] = []
        TransientDetector.computeWeights(&samples)
        #expect(samples.isEmpty)
    }

    @Test("Single sample unchanged")
    func singleSample() {
        var samples = [SampleData(min: -0.5, max: 0.5)]
        TransientDetector.computeWeights(&samples)
        #expect(samples[0].transientWeight == 0)
    }

    @Test("Constant amplitude has zero weights")
    func constantAmplitude() {
        var samples = [
            SampleData(min: -0.5, max: 0.5),
            SampleData(min: -0.5, max: 0.5),
            SampleData(min: -0.5, max: 0.5),
            SampleData(min: -0.5, max: 0.5)
        ]
        TransientDetector.computeWeights(&samples)

        for sample in samples {
            #expect(sample.transientWeight == 0)
        }
    }

    @Test("Spike has high weight at transition")
    func spikeDetection() {
        var samples = [
            SampleData(min: -0.1, max: 0.1),  // quiet
            SampleData(min: -0.1, max: 0.1),  // quiet
            SampleData(min: -0.9, max: 0.9),  // SPIKE
            SampleData(min: -0.1, max: 0.1),  // quiet
            SampleData(min: -0.1, max: 0.1)   // quiet
        ]
        TransientDetector.computeWeights(&samples)

        // The spike at index 2 should have highest weight (derivative from 0.1 to 0.9)
        // Index 3 should also have high weight (derivative from 0.9 to 0.1)
        let spikeWeight = samples[2].transientWeight
        let afterSpikeWeight = samples[3].transientWeight

        #expect(spikeWeight > 0.8, "Spike should have high weight")
        #expect(afterSpikeWeight > 0.8, "After spike should have high weight")

        // Quiet sections should have lower weights
        #expect(samples[1].transientWeight < spikeWeight)
        #expect(samples[4].transientWeight < afterSpikeWeight)
    }

    @Test("First element mirrors second")
    func firstElementMirrored() {
        var samples = [
            SampleData(min: -0.1, max: 0.1),
            SampleData(min: -0.5, max: 0.5),  // Jump here
            SampleData(min: -0.5, max: 0.5)
        ]
        TransientDetector.computeWeights(&samples)

        // First element should mirror second (both have same derivative)
        #expect(samples[0].transientWeight == samples[1].transientWeight)
    }

    @Test("Weights are normalized 0-1")
    func weightsNormalized() {
        var samples = [
            SampleData(min: -0.1, max: 0.1),
            SampleData(min: -0.3, max: 0.3),
            SampleData(min: -0.8, max: 0.8),
            SampleData(min: -0.2, max: 0.2),
            SampleData(min: -0.1, max: 0.1)
        ]
        TransientDetector.computeWeights(&samples)

        for sample in samples {
            #expect(sample.transientWeight >= 0)
            #expect(sample.transientWeight <= 1)
        }

        // At least one should be 1.0 (the max derivative)
        let maxWeight = samples.map(\.transientWeight).max() ?? 0
        #expect(maxWeight == 1.0)
    }

    @Test("Gradual increase has moderate weights")
    func gradualIncrease() {
        var samples = [
            SampleData(min: -0.1, max: 0.1),
            SampleData(min: -0.2, max: 0.2),
            SampleData(min: -0.3, max: 0.3),
            SampleData(min: -0.4, max: 0.4),
            SampleData(min: -0.5, max: 0.5)
        ]
        TransientDetector.computeWeights(&samples)

        // All derivatives are equal (0.1), so all weights should be equal
        let weights = samples.map(\.transientWeight)
        let firstWeight = weights[0]
        for weight in weights {
            #expect(weight == firstWeight)
        }
    }
}
