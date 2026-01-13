import AVFoundation
import Accelerate
import os

class GenerateTask {
    let audioBuffer: AVAudioPCMBuffer
    let samplesToPrepend: Int
    let samplesToAppend: Int
    private let isCancelled = OSAllocatedUnfairLock(initialState: false)

    init(
        audioBuffer: AVAudioPCMBuffer,
        samplesToPrepend: Int = 0,
        samplesToAppend: Int = 0
    ) {
        self.audioBuffer = audioBuffer
        self.samplesToPrepend = samplesToPrepend
        self.samplesToAppend = samplesToAppend
    }

    func cancel() {
        isCancelled.withLock { $0 = true }
    }

    func resume(
        width: CGFloat,
        renderSamples: SampleRange,
        displayMode: WaveformDisplayMode = .normal,
        completion: @escaping ([SampleData]) -> Void
    ) {
        var sampleData = [SampleData](repeating: .zero, count: Int(width))

        DispatchQueue.global(qos: .userInteractive).async {
            let channels = Int(self.audioBuffer.format.channelCount)
            let actualSampleCount = Int(self.audioBuffer.frameLength)
            let samplesPerPoint = renderSamples.count / Int(width)

            guard let floatChannelData = self.audioBuffer.floatChannelData else { return }
            guard samplesPerPoint > 0 else { return }

            DispatchQueue.concurrentPerform(iterations: Int(width)) { point in
                guard !self.isCancelled.withLock({ $0 }) else { return }

                // Calculate virtual sample range for this point
                let pointStartVirtual = renderSamples.lowerBound + (point * samplesPerPoint)
                let pointEndVirtual = pointStartVirtual + samplesPerPoint

                // Check if entirely in padding zones
                let fullyInPrepend = pointEndVirtual <= self.samplesToPrepend
                let fullyInAppend = pointStartVirtual >= (self.samplesToPrepend + actualSampleCount)

                if fullyInPrepend || fullyInAppend {
                    // Already .zero, skip
                    return
                }

                // Calculate actual buffer range (clamped to real audio)
                let actualStart = max(pointStartVirtual, self.samplesToPrepend) - self.samplesToPrepend
                let actualEnd = min(pointEndVirtual, self.samplesToPrepend + actualSampleCount) - self.samplesToPrepend
                let actualLength = actualEnd - actualStart

                guard actualLength > 0 else { return }

                var data: SampleData = .zero
                for channel in 0..<channels {
                    let pointer = floatChannelData[channel].advanced(by: actualStart)
                    let stride = vDSP_Stride(self.audioBuffer.stride)
                    let length = vDSP_Length(actualLength)

                    var value: Float = 0

                    vDSP_minv(pointer, stride, &value, length)
                    data.min = min(value, data.min)

                    vDSP_maxv(pointer, stride, &value, length)
                    data.max = max(value, data.max)
                }
                sampleData[point] = data
            }

            // Compute transient weights if in highlight mode
            if displayMode == .transientHighlight {
                self.computeTransientWeights(&sampleData)
            }

            DispatchQueue.main.async {
                guard !self.isCancelled.withLock({ $0 }) else { return }
                completion(sampleData)
            }
        }
    }

    private func computeTransientWeights(_ sampleData: inout [SampleData]) {
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

        // Normalize and apply sigmoid-like curve
        guard maxDerivative > 0.001 else { return }

        for i in 0..<sampleData.count {
            let normalized = derivatives[i] / maxDerivative
            // Apply curve to emphasize larger derivatives
            // Using sqrt for gentler curve, or pow(x, 0.5)
            sampleData[i].transientWeight = sqrt(normalized)
        }
    }
}
