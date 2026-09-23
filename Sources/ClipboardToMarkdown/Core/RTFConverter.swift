import Foundation
import AppKit

/// Converts RTF / RTFD data to HTML via an `NSAttributedString` round-trip,
/// so it can then flow through the same Turndown pipeline as native HTML.
///
/// `@MainActor` — `NSAttributedString`'s HTML writer touches text system
/// machinery that is safest on the main thread.
@MainActor
struct RTFConverter {

    enum RTFError: LocalizedError {
        case unreadable
        case notEncodable
        var errorDescription: String? {
            switch self {
            case .unreadable: return "The copied styled text could not be read."
            case .notEncodable: return "The copied styled text could not be converted."
            }
        }
    }

    /// RTF/RTFD `Data` → HTML string.
    func html(from data: Data) throws -> String {
        let attributed: NSAttributedString
        do {
            attributed = try NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.rtfd],
                documentAttributes: nil
            )
        } catch {
            // Fall back to plain RTF if RTFD parsing fails.
            guard let plain = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
            ) else {
                throw RTFError.unreadable
            }
            return try htmlString(from: plain)
        }
        return try htmlString(from: attributed)
    }

    private func htmlString(from attributed: NSAttributedString) throws -> String {
        let htmlData = try attributed.data(
            from: NSRange(location: 0, length: attributed.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.html]
        )
        guard let html = String(data: htmlData, encoding: .utf8) else {
            throw RTFError.notEncodable
        }
        return html
    }
}
