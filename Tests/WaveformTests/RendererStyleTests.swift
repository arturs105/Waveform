import Testing
import SwiftUI
import UIKit
@testable import Waveform

/// Renders the waveform for each style flag and checks the drawing actually
/// changes — a toggle that looks enabled but draws nothing is the failure mode
/// these guard against.
@MainActor
@Suite("Renderer style rendering")
struct RendererStyleTests {

    private static let size = CGSize(width: 240, height: 64)

    /// A quiet passage, a sharp attack with decay, then a quiet tail.
    private func sampleData() -> [SampleData] {
        var peaks = [Float](repeating: 0.04, count: 120)
        for index in 40..<44 { peaks[index] = 0.9 }
        for index in 44..<70 { peaks[index] = 0.9 - Float(index - 44) * 0.03 }
        var data = peaks.map { SampleData(min: -$0, max: $0, rms: $0 * 0.45) }
        TransientDetector.computeWeights(&data, adaptive: true)
        return data
    }

    private func pixels(style: WaveformStyle) -> [UInt8] {
        let view = Renderer(waveformData: sampleData(), style: style)
            .frame(width: Self.size.width, height: Self.size.height)
            .foregroundStyle(Color.blue)
            .background(Color.black)
        let imageRenderer = ImageRenderer(content: view)
        imageRenderer.scale = 1
        guard let cgImage = imageRenderer.uiImage?.cgImage else { return [] }

        let width = cgImage.width
        let height = cgImage.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        bytes.withUnsafeMutableBytes { raw in
            let context = CGContext(
                data: raw.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
            context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return bytes
    }

    @Test("Baseline draws something")
    func baselineDrawsPixels() {
        let baseline = pixels(style: .normal)
        #expect(!baseline.isEmpty)
        #expect(baseline.contains { $0 > 0 })
    }

    @Test(
        "Each style flag changes the drawing",
        arguments: [
            ("decibelScale", WaveformStyle(decibelScale: true)),
            ("peakOutline", WaveformStyle(peakOutline: true)),
            ("legacyTransientScaling", WaveformStyle(legacyTransientScaling: true))
        ]
    )
    func flagChangesDrawing(name: String, style: WaveformStyle) {
        let baseline = pixels(style: .normal)
        let styled = pixels(style: style)
        #expect(!styled.isEmpty, "\(name) produced no image")
        #expect(styled != baseline, "\(name) drew an identical image")
    }
}
