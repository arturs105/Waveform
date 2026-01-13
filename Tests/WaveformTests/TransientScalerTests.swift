import Testing
@testable import Waveform

@Suite("TransientScaler Tests")
struct TransientScalerTests {

    // MARK: - Zero weight (non-transient)

    @Test("Zero weight attenuates to 15%")
    func zeroWeightAttenuation() {
        let result = TransientScaler.scaleAmplitude(1.0, weight: 0)
        #expect(result == TransientScaler.nonTransientAttenuation)
    }

    @Test("Zero weight preserves sign for negative amplitude")
    func zeroWeightNegative() {
        let result = TransientScaler.scaleAmplitude(-1.0, weight: 0)
        #expect(result == -TransientScaler.nonTransientAttenuation)
    }

    @Test("Zero weight with zero amplitude returns zero")
    func zeroWeightZeroAmplitude() {
        let result = TransientScaler.scaleAmplitude(0, weight: 0)
        #expect(result == 0)
    }

    // MARK: - Full weight (strong transient)

    @Test("Full weight preserves full amplitude")
    func fullWeightPreservesAmplitude() {
        let result = TransientScaler.scaleAmplitude(1.0, weight: 1.0)
        // With weight=1: attenuation=1.0, scaleFactor=0.4, pow(1,0.4)=1
        #expect(result == 1.0)
    }

    @Test("Full weight preserves sign for negative amplitude")
    func fullWeightNegative() {
        let result = TransientScaler.scaleAmplitude(-1.0, weight: 1.0)
        #expect(result == -1.0)
    }

    @Test("Full weight with zero amplitude returns zero")
    func fullWeightZeroAmplitude() {
        let result = TransientScaler.scaleAmplitude(0, weight: 1.0)
        #expect(result == 0)
    }

    // MARK: - Partial weights

    @Test("Half weight gives intermediate result")
    func halfWeight() {
        let result = TransientScaler.scaleAmplitude(1.0, weight: 0.5)
        // Should be between 0.15 (zero weight) and 1.0 (full weight)
        #expect(result > TransientScaler.nonTransientAttenuation)
        #expect(result < 1.0)
    }

    @Test("Higher weight gives larger result")
    func higherWeightLargerResult() {
        let lowWeight = TransientScaler.scaleAmplitude(0.5, weight: 0.2)
        let highWeight = TransientScaler.scaleAmplitude(0.5, weight: 0.8)
        #expect(highWeight > lowWeight)
    }

    // MARK: - Small amplitudes

    @Test("Small amplitude with high weight is expanded")
    func smallAmplitudeExpansion() {
        let result = TransientScaler.scaleAmplitude(0.1, weight: 1.0)
        // pow(0.1, 0.4) ≈ 0.398, with attenuation=1.0
        #expect(result > 0.1, "Small transient amplitude should be expanded")
    }

    @Test("Small amplitude with low weight is compressed")
    func smallAmplitudeCompression() {
        let result = TransientScaler.scaleAmplitude(0.5, weight: 0)
        // 0.5 * 0.15 = 0.075
        #expect(result < 0.5, "Non-transient should be attenuated")
        #expect(abs(result - 0.5 * TransientScaler.nonTransientAttenuation) < 0.001)
    }

    // MARK: - Symmetry

    @Test("Positive and negative amplitudes are symmetric")
    func symmetry() {
        let weights: [Float] = [0, 0.25, 0.5, 0.75, 1.0]
        let amplitude: Float = 0.7

        for weight in weights {
            let positive = TransientScaler.scaleAmplitude(amplitude, weight: weight)
            let negative = TransientScaler.scaleAmplitude(-amplitude, weight: weight)
            #expect(positive == -negative)
        }
    }

    // MARK: - Constants

    @Test("Non-transient attenuation is 15%")
    func attenuationConstant() {
        #expect(TransientScaler.nonTransientAttenuation == 0.15)
    }

    @Test("Expansion exponent is 1.5")
    func exponentConstant() {
        #expect(TransientScaler.transientExpansionExponent == 1.5)
    }
}
