import Accelerate
import Foundation

/// Computes per-column transient weights for waveform samples.
enum TransientDetector {
    /// Half-window, in columns, used by the adaptive detector's local normalisation.
    static let windowRadius = 25
    /// Columns quieter than this never score as transients (keeps noise floors clean).
    static let silenceFloor: Float = 0.005
    /// Smallest dB span used as the adaptive normalisation denominator.
    static let minimumFluxSpan: Float = 1.0
    /// Absolute rise, in dB, below which a column is never an onset. Local
    /// normalisation alone would promote the tiny wobble of a steady tone or
    /// room noise into a full-strength "transient".
    static let minimumFluxDecibels: Float = 3

    /// Computes transient weights for the given sample data (modified in place).
    /// - Parameters:
    ///   - sampleData: Column data to annotate.
    ///   - adaptive: `true` selects the rectified, dB-domain, locally normalised
    ///     detector; `false` keeps the original global-max amplitude derivative.
    static func computeWeights(_ sampleData: inout [SampleData], adaptive: Bool = false) {
        guard sampleData.count > 1 else { return }
        if adaptive {
            computeAdaptiveWeights(&sampleData)
        } else {
            computeLegacyWeights(&sampleData)
        }
    }

    // MARK: - Adaptive

    /// Onset strength from half-wave rectified dB flux, normalised against a local
    /// median. Three fixes over the legacy detector:
    /// - rectified, so a decay no longer scores as high as an attack;
    /// - dB domain, so a sharp attack in a quiet passage registers like a loud one;
    /// - local (not global) normalisation, so one loud hit can't floor the rest.
    private static func computeAdaptiveWeights(_ sampleData: inout [SampleData]) {
        let count = sampleData.count

        let peaks = sampleData.map { max(abs($0.min), abs($0.max)) }
        let energy = sampleData.enumerated().map { index, sample -> Float in
            // RMS tracks energy better than peak; fall back to peak when absent.
            let level = max(sample.rms > 0 ? sample.rms : peaks[index], 1e-5)
            return 20 * log10(level)
        }

        var flux = [Float](repeating: 0, count: count)
        for index in 1..<count {
            flux[index] = max(0, energy[index] - energy[index - 1])
        }
        flux[0] = flux[1]

        var window = [Float]()
        window.reserveCapacity(2 * windowRadius + 1)

        for index in 0..<count {
            guard peaks[index] > silenceFloor, flux[index] >= minimumFluxDecibels else {
                sampleData[index].transientWeight = 0
                continue
            }
            let lower = max(0, index - windowRadius)
            let upper = min(count - 1, index + windowRadius)
            window.removeAll(keepingCapacity: true)
            window.append(contentsOf: flux[lower...upper])
            window.sort()

            let median = window[window.count / 2]
            let localMax = window[window.count - 1]
            let span = max(localMax - median, minimumFluxSpan)
            let weight = (flux[index] - median) / span
            sampleData[index].transientWeight = min(max(weight, 0), 1)
        }
    }

    // MARK: - Legacy

    /// Transient weight based on the absolute rate of amplitude change,
    /// normalised against the largest derivative in view.
    private static func computeLegacyWeights(_ sampleData: inout [SampleData]) {
        // Compute peak amplitude for each sample
        let peaks = sampleData.map { max(abs($0.min), abs($0.max)) }

        // Compute derivative (rate of change) for each sample
        var derivatives = [Float](repeating: 0, count: peaks.count)
        for i in 1..<peaks.count {
            derivatives[i] = abs(peaks[i] - peaks[i - 1])
        }
        // Mirror first element to avoid edge case where first sample is always 0
        derivatives[0] = derivatives[1]

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

    /// Indices of local onset peaks — used to place transient markers.
    /// - Parameters:
    ///   - sampleData: Annotated column data.
    ///   - threshold: Minimum weight for a column to qualify.
    ///   - minimumSpacing: Minimum gap, in columns, between two markers.
    static func onsetIndices(
        in sampleData: [SampleData],
        threshold: Float = 0.5,
        minimumSpacing: Int = 3
    ) -> [Int] {
        var result: [Int] = []
        for index in sampleData.indices {
            let weight = sampleData[index].transientWeight
            guard weight >= threshold else { continue }
            // Keep only local maxima so one attack yields one marker.
            let previous = index > 0 ? sampleData[index - 1].transientWeight : 0
            let next = index < sampleData.count - 1 ? sampleData[index + 1].transientWeight : 0
            guard weight >= previous, weight >= next else { continue }
            if let last = result.last, index - last < minimumSpacing {
                if weight > sampleData[last].transientWeight { result[result.count - 1] = index }
                continue
            }
            result.append(index)
        }
        return result
    }
}
