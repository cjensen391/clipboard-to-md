import XCTest
import AppKit
@testable import ClipboardToMarkdown

/// Renders a string as black text on a white background into an `NSImage`,
/// large enough for Vision to recognize reliably.
func renderTextImage(_ text: String, size: NSSize = NSSize(width: 600, height: 160)) -> NSImage {
    let image = NSImage(size: size)
    image.lockFocus()
    NSColor.white.setFill()
    NSRect(origin: .zero, size: size).fill()
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 48),
        .foregroundColor: NSColor.black
    ]
    (text as NSString).draw(at: NSPoint(x: 20, y: 50), withAttributes: attrs)
    image.unlockFocus()
    return image
}

final class OCRServiceTests: XCTestCase {

    func testRecognizesRenderedText() throws {
        let image = renderTextImage("Hello Vision")
        let result = OCRService().recognizeText(in: image)
        let recognized = try XCTUnwrap(result, "OCR returned nil for a clear text image")
        // Vision may vary spacing/case slightly; assert on the distinctive tokens.
        XCTAssertTrue(recognized.contains("Hello"), "expected 'Hello', got: \(recognized)")
        XCTAssertTrue(recognized.contains("Vision"), "expected 'Vision', got: \(recognized)")
    }

    func testReturnsNilForBlankImage() {
        let blank = NSImage(size: NSSize(width: 200, height: 200))
        blank.lockFocus()
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: 200, height: 200).fill()
        blank.unlockFocus()
        XCTAssertNil(OCRService().recognizeText(in: blank), "blank image should yield no text")
    }
}

final class ImageConversionTests: XCTestCase {

    @MainActor
    func testImageWithTextEmbedsRecognizedText() async throws {
        let service = ConversionService(engine: TurndownEngine())
        let image = renderTextImage("Meeting Notes")
        let result = try await service.convert(.image(image))

        XCTAssertTrue(result.markdown.contains("!["), "expected an image embed, got:\n\(result.markdown)")
        XCTAssertTrue(result.markdown.contains("Meeting"), "expected recognized text in markdown, got:\n\(result.markdown)")
        XCTAssertEqual(result.sidecars.count, 1, "expected a single PNG sidecar")
        XCTAssertTrue(result.sidecars.first?.name.hasSuffix(".png") ?? false)
        // Filename is derived from the recognized text, not a timestamp.
        XCTAssertFalse(result.suggestedName.hasPrefix("Clipboard-"), "name should come from OCR text, got \(result.suggestedName)")
    }
}

final class TurndownEngineTests: XCTestCase {

    @MainActor
    func testConvertsHTMLTableToGFM() async throws {
        let engine = TurndownEngine()
        engine.warmUp()
        let html = "<table><thead><tr><th>A</th><th>B</th></tr></thead>"
            + "<tbody><tr><td>1</td><td>2</td></tr></tbody></table>"
        let md = try await engine.convert(html: html)
        XCTAssertTrue(md.contains("| A | B |"), "expected a GFM header row, got:\n\(md)")
        XCTAssertTrue(md.contains("| --- | --- |"), "expected a GFM separator row, got:\n\(md)")
    }

    @MainActor
    func testConvertsHeadingAndBold() async throws {
        let engine = TurndownEngine()
        engine.warmUp()
        let md = try await engine.convert(html: "<h1>Title</h1><p>Some <strong>bold</strong> text.</p>")
        XCTAssertTrue(md.contains("# Title"))
        XCTAssertTrue(md.contains("**bold**"))
    }
}

final class FilenameGeneratorTests: XCTestCase {

    func testUsesFirstHeading() {
        let name = FilenameGenerator().suggestedName(for: "# My Great Note\n\nbody")
        XCTAssertEqual(name, "My Great Note")
    }

    func testFallsBackToFirstLine() {
        let name = FilenameGenerator().suggestedName(for: "Just a line of text\nmore")
        XCTAssertEqual(name, "Just a line of text")
    }

    func testTimestampFallbackForEmpty() {
        let date = Date(timeIntervalSince1970: 0) // 1970-01-01 00:00:00 UTC
        let name = FilenameGenerator().suggestedName(for: "   \n  ", now: date)
        XCTAssertTrue(name.hasPrefix("Clipboard-"), "got \(name)")
    }

    func testStripsIllegalCharacters() {
        let name = FilenameGenerator().suggestedName(for: "# a/b:c*d")
        XCTAssertFalse(name.contains("/"))
        XCTAssertFalse(name.contains(":"))
        XCTAssertFalse(name.contains("*"))
    }
}
