import AVFoundation
import SwiftUI

/// An object that generates waveform data from an `AVAudioFile`.
public class WaveformGenerator: ObservableObject {
    /// The audio file initially used to create the generator.
    public let audioFile: AVAudioFile
    /// An audio buffer containing the original audio file decoded as PCM data.
    public let audioBuffer: AVAudioPCMBuffer

    /// Number of silent samples to prepend virtually (for time alignment).
    public private(set) var samplesToPrepend: Int
    /// Number of silent samples to append virtually (for length equalization).
    public private(set) var samplesToAppend: Int
    /// Global total samples for consistent scaling across all waveforms.
    public var globalTotalSamples: Int?

    /// Total samples including virtual padding.
    public var totalVirtualSamples: Int {
        Int(audioBuffer.frameLength) + samplesToPrepend + samplesToAppend
    }

    /// Effective total for scaling (uses global if set, otherwise local).
    public var effectiveTotalSamples: Int {
        globalTotalSamples ?? totalVirtualSamples
    }

    /// Normalized visible range start (0-1)
    public var visibleRangeStart: CGFloat {
        guard effectiveTotalSamples > 0 else { return 0 }
        return CGFloat(renderSamples.lowerBound) / CGFloat(effectiveTotalSamples)
    }

    /// Normalized visible range end (0-1)
    public var visibleRangeEnd: CGFloat {
        guard effectiveTotalSamples > 0 else { return 1 }
        return CGFloat(renderSamples.upperBound) / CGFloat(effectiveTotalSamples)
    }

    /// Whether currently at an edge (for rubber band effect)
    public var isAtLeadingEdge: Bool { renderSamples.lowerBound == 0 }
    public var isAtTrailingEdge: Bool { renderSamples.upperBound == effectiveTotalSamples }

    private var generateTask: GenerateTask?
    @Published private(set) var sampleData: [SampleData] = []

    /// The range of samples to display. The value will update as the waveform is zoomed and panned.
    @Published public var renderSamples: SampleRange {
        didSet { refreshData() }
    }

    var width: CGFloat = 0 {     // would publishing this be bad?
        didSet { refreshData() }
    }

    /// Creates an instance from an `AVAudioFile` with optional virtual padding.
    /// - Parameters:
    ///   - audioFile: The audio file to generate waveform data from.
    ///   - samplesToPrepend: Number of silent samples to prepend virtually.
    ///   - samplesToAppend: Number of silent samples to append virtually.
    ///   - globalTotalSamples: Global total for consistent scaling across waveforms.
    public init?(
        audioFile: AVAudioFile,
        samplesToPrepend: Int = 0,
        samplesToAppend: Int = 0,
        globalTotalSamples: Int? = nil
    ) {
        let capacity = AVAudioFrameCount(audioFile.length)
        guard let audioBuffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: capacity) else { return nil }

        do {
            try audioFile.read(into: audioBuffer)
        } catch let error {
            print(error.localizedDescription)
            return nil
        }

        self.audioFile = audioFile
        self.audioBuffer = audioBuffer
        self.samplesToPrepend = samplesToPrepend
        self.samplesToAppend = samplesToAppend
        self.globalTotalSamples = globalTotalSamples
        let localTotal = Int(capacity) + samplesToPrepend + samplesToAppend
        self.renderSamples = 0..<(globalTotalSamples ?? localTotal)
    }
    
    func refreshData() {
        generateTask?.cancel()
        guard width > 0 else { return }
        generateTask = GenerateTask(
            audioBuffer: audioBuffer,
            samplesToPrepend: samplesToPrepend,
            samplesToAppend: samplesToAppend
        )

        generateTask?.resume(width: width, renderSamples: renderSamples) { sampleData in
            self.sampleData = sampleData
        }
    }

    /// Updates the virtual padding without reloading the audio buffer.
    public func updatePadding(samplesToPrepend: Int, samplesToAppend: Int) {
        let prependDelta = samplesToPrepend - self.samplesToPrepend
        self.samplesToPrepend = samplesToPrepend
        self.samplesToAppend = samplesToAppend

        // Shift renderSamples to keep viewing the same audio portion
        let newStart = max(0, renderSamples.lowerBound + prependDelta)
        let newEnd = min(newStart + renderSamples.count, totalVirtualSamples)
        renderSamples = newStart..<newEnd
    }
    
    // MARK: Conversions
    func position(of sample: Int) -> CGFloat {
        let radio = width / CGFloat(renderSamples.count)
        return CGFloat(sample - renderSamples.lowerBound) * radio
    }
    
    func sample(for position: CGFloat) -> Int {
        guard width > 0 else { return renderSamples.lowerBound }
        let ratio = CGFloat(renderSamples.count) / width
        let sample = renderSamples.lowerBound + Int(position * ratio)
        return min(max(0, sample), effectiveTotalSamples)
    }

    func sample(_ oldSample: Int, with offset: CGFloat) -> Int {
        guard width > 0 else { return oldSample }
        let ratio = CGFloat(renderSamples.count) / width
        let sample = oldSample + Int(offset * ratio)
        return min(max(0, sample), effectiveTotalSamples)
    }
}
