import XCTest
@testable import ClipboardToMarkdown

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
