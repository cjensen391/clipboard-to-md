import Foundation
import AppKit

/// Orchestrates payload → `MarkdownResult`. UI-agnostic and unit-testable
/// (the only main-thread dependencies are the engine and the RTF converter,
/// both `@MainActor`).
@MainActor
final class ConversionService {

    enum ConversionError: LocalizedError {
        case nothingConvertible
        var errorDescription: String? {
            switch self {
            case .nothingConvertible:
                return "There's nothing on the clipboard to convert. Copy some text or an image and try again."
            }
        }
    }

    private let engine: TurndownEngine
    private let rtfConverter = RTFConverter()
    private let imageSaver = ImageSaver()
    private let filenameGenerator = FilenameGenerator()
    private let ocr = OCRService()

    init(engine: TurndownEngine) {
        self.engine = engine
    }

    /// Warm the underlying WebView so the first real conversion is instant.
    func warmUp() {
        engine.warmUp()
    }

    func convert(_ payload: ClipboardPayload) async throws -> MarkdownResult {
        switch payload {
        case .html(let html):
            return try await convertHTML(html)

        case .rtf(let data):
            let html = try rtfConverter.html(from: data)
            return try await convertHTML(html)

        case .image(let image):
            return try convertImage(image)

        case .files(let urls):
            return convertFiles(urls)

        case .plainText(let text):
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return MarkdownResult(
                markdown: text,
                suggestedName: filenameGenerator.suggestedName(for: trimmed)
            )

        case .empty:
            throw ConversionError.nothingConvertible
        }
    }

    private func convertHTML(_ html: String) async throws -> MarkdownResult {
        let markdown = try await engine.convert(html: html)
        let trimmed = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        return MarkdownResult(
            markdown: trimmed,
            suggestedName: filenameGenerator.suggestedName(for: trimmed)
        )
    }

    private func convertImage(_ image: NSImage) throws -> MarkdownResult {
        // Recognize any text in the image (macOS Vision OCR). When text is
        // found, name the file after it and append the text below the embed;
        // otherwise fall back to a timestamped name and a bare image embed.
        let recognized = ocr.recognizeText(in: image)

        let name = filenameGenerator.suggestedName(for: recognized ?? "")
        let imageName = "\(name).png"
        let png = try imageSaver.pngData(from: image)

        var markdown = "![](\(imageName))\n"
        if let recognized, !recognized.isEmpty {
            markdown += "\n\(recognized)\n"
        }

        return MarkdownResult(
            markdown: markdown,
            suggestedName: name,
            sidecars: [Sidecar(name: imageName, data: png)]
        )
    }

    private func convertFiles(_ urls: [URL]) -> MarkdownResult {
        let lines = urls.map { url -> String in
            let name = url.lastPathComponent
            return "- [\(name)](\(url.absoluteString))"
        }
        let markdown = lines.joined(separator: "\n") + "\n"
        let base = urls.count == 1
            ? urls[0].deletingPathExtension().lastPathComponent
            : filenameGenerator.suggestedName(for: "")
        return MarkdownResult(markdown: markdown, suggestedName: base)
    }
}
