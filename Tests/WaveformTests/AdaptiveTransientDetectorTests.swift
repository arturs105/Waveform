import Testing
@testable import Waveform

@Suite("Adaptive TransientDetector Tests")
struct AdaptiveTransientDetectorTests {

    /// Builds columns from peak levels, mirrored around the centre line.
    private func columns(_ peaks: [Float]) -> [SampleData] {
        peaks.map { SampleData(min: -$0, max: $0, rms: $0 * 0.7) }
    }

    @Test("Attack scores higher than the decay that follows it")
    func rectifiedFlux() {
        var samples = columns([0.05, 0.05, 0.9, 0.6, 0.3, 0.1, 0.05])
        TransientDetector.computeWeights(&samples, adaptive: true)

        let attack = samples[2].transientWeight
        let decay = samples.dropFirst(3).map(\.transientWeight).max() ?? 0
        #expect(attack > decay)
        #expect(attack > 0.5)
    }

    @Test("Legacy detector scores the decay as strongly as the attack")
    func legacyDetectorMarksDecays() {
        var samples = columns([0.05, 0.05, 0.9, 0.05, 0.05])
        TransientDetector.computeWeights(&samples, adaptive: false)

        // Rise and fall have identical magnitude, so both score 1 — the defect
        // the adaptive detector fixes.
        #expect(samples[2].transientWeight == samples[3].transientWeight)
    }

    @Test("Quiet attack still registers next to a loud one")
    func localNormalization() {
        var peaks = [Float](repeating: 0.02, count: 60)
        // Loud hit early, quiet hit far enough away to sit in its own window.
        peaks[10] = 0.95
        peaks[11] = 0.7
        peaks[50] = 0.08
        peaks[51] = 0.06
        var samples = columns(peaks)
        TransientDetector.computeWeights(&samples, adaptive: true)

        #expect(samples[10].transientWeight > 0.5)
        #expect(samples[50].transientWeight > 0.5)
    }

    @Test("Near-silence never scores")
    func silenceFloor() {
        var samples = columns([0.0001, 0.0001, 0.004, 0.0001])
        TransientDetector.computeWeights(&samples, adaptive: true)

        #expect(samples.allSatisfy { $0.transientWeight == 0 })
    }

    @Test("One marker per attack")
    func onsetIndices() {
        var peaks = [Float](repeating: 0.03, count: 40)
        for index in [10, 11, 12, 25, 26] { peaks[index] = 0.8 }
        var samples = columns(peaks)
        TransientDetector.computeWeights(&samples, adaptive: true)

        let onsets = TransientDetector.onsetIndices(in: samples)
        #expect(onsets.count == 2)
        #expect(onsets.contains(10))
        #expect(onsets.contains(25))
    }
}

@Suite("AmplitudeMapper Tests")
struct AmplitudeMapperTests {

    @Test("Full scale maps to full height")
    func fullScale() {
        #expect(abs(AmplitudeMapper.decibel(1.0) - 1.0) < 0.0001)
    }

    @Test("Floor and below map to zero")
    func floor() {
        #expect(AmplitudeMapper.decibel(0.01) == 0)  // -40 dB
        #expect(AmplitudeMapper.decibel(0) == 0)
    }

    @Test("Sign is preserved")
    func sign() {
        #expect(AmplitudeMapper.decibel(-0.5) == -AmplitudeMapper.decibel(0.5))
    }

    @Test("Quiet detail is lifted well above its linear height")
    func liftsQuietDetail() {
        // -20 dB: linear draws 0.1 of full height, dB draws half of it.
        let mapped = AmplitudeMapper.decibel(0.1)
        #expect(abs(mapped - 0.5) < 0.01)
    }

    @Test("Style off leaves amplitude untouched")
    func identity() {
        #expect(AmplitudeMapper.map(0.42, weight: 1, style: .normal) == 0.42)
    }

    @Test("Style routes through dB when enabled")
    func decibelStyle() {
        let style = WaveformStyle(decibelScale: true)
        #expect(AmplitudeMapper.map(1.0, weight: 0, style: style) == AmplitudeMapper.decibel(1.0))
    }
}
