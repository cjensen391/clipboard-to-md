import Foundation
import AppKit
import Vision

/// Runs macOS Vision text recognition (OCR) over an `NSImage` and returns the
/// recognized text in natural reading order.
///
/// Requires macOS 14+ (the project's deployment target); `VNRecognizeTextRequest`
/// and `.accurate` recognition are available well below that.
struct OCRService {

    /// The recognized text, or `nil` when Vision produced no usable candidates
    /// (e.g. a photo with no legible text, a solid-color image, or an icon).
    func recognizeText(in image: NSImage) -> String? {
        guard let cgImage = cgImage(from: image) else { return nil }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let observations = request.results, !observations.isEmpty else {
            return nil
        }

        // Vision returns observations in no guaranteed order. Sort into reading
        // order: top-to-bottom (Vision's y origin is bottom-left, so larger y is
        // higher on the page), then left-to-right for items on the same line.
        let sorted = observations.sorted { lhs, rhs in
            let ly = lhs.boundingBox.origin.y
            let ry = rhs.boundingBox.origin.y
            // Treat observations within a small vertical band as the same line.
            if abs(ly - ry) > 0.01 {
                return ly > ry
            }
            return lhs.boundingBox.origin.x < rhs.boundingBox.origin.x
        }

        let lines = sorted.compactMap { $0.topCandidates(1).first?.string }
        let text = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    private func cgImage(from image: NSImage) -> CGImage? {
        var rect = CGRect(origin: .zero, size: image.size)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }
}
