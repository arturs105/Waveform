import SwiftUI
import AVFoundation
import Accelerate

/// A range of integers representing samples from an AVAudioFile.
public typealias SampleRange = Range<Int>

/// An interactive waveform generated from an `AVAudioFile`.
public struct Waveform: View {
    @ObservedObject var generator: WaveformGenerator

    @Binding var zoomValue: CGFloat
    @Binding var panValue: CGFloat
    @Binding var alignmentPanValue: CGFloat
    @Binding var alignmentSampleOffset: Int
    @Binding var selectedSamples: SampleRange
    @Binding var selectionEnabled: Bool

    /// Creates an instance powered by the supplied generator.
    /// - Parameters:
    ///   - generator: The object that will supply waveform data.
    ///   - selectedSamples: A binding to a `SampleRange` to update with the selection chosen in the waveform.
    ///   - selectionEnabled: A binding to enable/disable selection on the waveform
    ///   - alignmentSampleOffset: Binding to track accumulated alignment offset in samples
    public init(
        generator: WaveformGenerator,
        selectedSamples: Binding<SampleRange>,
        selectionEnabled: Binding<Bool>,
        zoomValue: Binding<CGFloat>,
        panValue: Binding<CGFloat>,
        alignmentPanValue: Binding<CGFloat>,
        alignmentSampleOffset: Binding<Int>
    ) {
        self.generator = generator
        self._selectedSamples = selectedSamples
        self._selectionEnabled = selectionEnabled
        self._zoomValue = zoomValue
        self._panValue = panValue
        self._alignmentPanValue = alignmentPanValue
        self._alignmentSampleOffset = alignmentSampleOffset
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // invisible rectangle needed to register gestures that aren't on top of the waveform
                Rectangle()
                    .foregroundColor(Color(.systemBackground).opacity(0.01))

                Renderer(waveformData: generator.sampleData)
                    .preference(key: SizeKey.self, value: geometry.size)

                if selectionEnabled {
                    Highlight(selectedSamples: selectedSamples)
                        .foregroundColor(.accentColor)
                        .opacity(0.7)
                }
            }
            .padding(.bottom, selectionEnabled ? 30 : 0)

            if selectionEnabled {
                StartHandle(selectedSamples: $selectedSamples)
                    .foregroundColor(.accentColor)
                EndHandle(selectedSamples: $selectedSamples)
                    .foregroundColor(.accentColor)
            }
        }
//        .gesture(SimultaneousGesture(zoom, pan))
//        .gesture(pan)
        .environmentObject(generator)
        .onPreferenceChange(SizeKey.self) {
            guard generator.width != $0.width else { return }
            generator.width = $0.width
        }
        .onChange(of: zoomValue) { oldValue, newValue in
            zoom(amount: newValue)
        }
        .onChange(of: panValue) { oldValue, newValue in
            pan(offset: newValue)
        }
        .onChange(of: alignmentPanValue) { oldValue, newValue in
            pan(offset: newValue, updateAlignmentOffset: true)
        }
    }
    
    func zoom(amount: CGFloat) {
        let count = generator.renderSamples.count
        let newCount = CGFloat(count) / amount
        let delta = (count - Int(newCount)) / 2
        let renderStartSample = max(0, generator.renderSamples.lowerBound + delta)
        let renderEndSample = min(generator.renderSamples.upperBound - delta, generator.effectiveTotalSamples)
        generator.renderSamples = renderStartSample..<renderEndSample
    }

    func pan(offset: CGFloat, updateAlignmentOffset: Bool = false) {
        let count = generator.renderSamples.count
        var startSample = generator.sample(generator.renderSamples.lowerBound, with: offset)
        var endSample = startSample + count

        if startSample < 0 {
            startSample = 0
            endSample = generator.renderSamples.count
        } else if endSample > generator.effectiveTotalSamples {
            endSample = generator.effectiveTotalSamples
            startSample = endSample - generator.renderSamples.count
        }

        if updateAlignmentOffset {
            let difference = generator.renderSamples.lowerBound - startSample
            alignmentSampleOffset += difference
        }

        generator.renderSamples = startSample..<endSample
    }
}
