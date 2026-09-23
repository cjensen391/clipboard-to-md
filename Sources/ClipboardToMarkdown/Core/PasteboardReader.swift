import Foundation
import AppKit
import UniformTypeIdentifiers

/// Reads `NSPasteboard` and picks the richest usable representation.
///
/// Priority: file URLs → HTML → RTFD → RTF → image → plain text → empty.
/// Rich sources (Safari, Docs) put HTML + RTF + string on the pasteboard at
/// once; taking HTML first yields the best conversion fidelity.
struct PasteboardReader {

    func read(_ pasteboard: NSPasteboard = .general) -> ClipboardPayload {
        // 1. File URLs copied in Finder. Guard against the pseudo file-URL that
        //    some apps write for promised/dragged text; require real files.
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self],
                                             options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !urls.isEmpty {
            return .files(urls)
        }

        // 2. HTML — richest for web/doc content.
        if let html = htmlString(from: pasteboard), !html.isEmpty {
            return .html(html)
        }

        // 3. RTFD (attributed text with attachments).
        if let rtfd = data(from: pasteboard, type: "com.apple.flat-rtfd") {
            return .rtf(rtfd)
        }

        // 4. RTF.
        if let rtf = data(from: pasteboard, type: NSPasteboard.PasteboardType.rtf.rawValue) {
            return .rtf(rtf)
        }

        // 5. Image (screenshots, copied images).
        if pasteboard.canReadItem(withDataConformingToTypes: [UTType.png.identifier,
                                                              UTType.tiff.identifier]),
           let image = NSImage(pasteboard: pasteboard) {
            return .image(image)
        }

        // 6. Plain text.
        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            return .plainText(text)
        }

        return .empty
    }

    /// Read HTML, decoding the raw bytes if the OS didn't hand back a string.
    private func htmlString(from pasteboard: NSPasteboard) -> String? {
        let htmlType = NSPasteboard.PasteboardType.html
        if let s = pasteboard.string(forType: htmlType) {
            return s
        }
        if let data = pasteboard.data(forType: htmlType) {
            return String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1)
        }
        return nil
    }

    private func data(from pasteboard: NSPasteboard, type: String) -> Data? {
        pasteboard.data(forType: NSPasteboard.PasteboardType(type))
    }
}
