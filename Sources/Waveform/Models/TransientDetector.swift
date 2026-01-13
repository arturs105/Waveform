import Accelerate

/// Computes transient weights for waveform samples based on amplitude derivative.
enum TransientDetector {
    /// Computes transient weights for the given sample data.
    /// Transient weight is based on the rate of amplitude change (derivative).
    /// - Parameter sampleData: Array of sample data to process (modified in place)
    static func computeWeights(_ sampleData: inout [SampleData]) {
        guard sampleData.count > 1 else { return }

        // Compute peak amplitude for each sample
        let peaks = sampleData.map { max(abs($0.min), abs($0.max)) }

        // Compute derivative (rate of change) for each sample
        var derivatives = [Float](repeating: 0, count: peaks.count)
        for i in 1..<peaks.count {
            derivatives[i] = abs(peaks[i] - peaks[i - 1])
        }
        // Mirror first element to avoid edge case where first sample is always 0
        if peaks.count > 1 {
            derivatives[0] = derivatives[1]
        }

        // Find max derivative for normalization
        var maxDerivative: Float = 0
        vDSP_maxv(derivatives, 1, &maxDerivative, vDSP_Length(derivatives.count))

        // Normalize and apply sqrt curve
        guard maxDerivative > 0.001 else { return }

        for i in 0..<sampleData.count {
            let normalized = derivatives[i] / maxDerivative
            // Apply sqrt curve to emphasize larger derivatives
            sampleData[i].transientWeight = sqrt(normalized)
        }
    }
}
