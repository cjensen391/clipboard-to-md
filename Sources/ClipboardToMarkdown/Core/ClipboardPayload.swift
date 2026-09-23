import Foundation
import AppKit

/// The richest usable representation pulled off the pasteboard.
/// Ordering of the reader's decision tree defines fidelity priority.
enum ClipboardPayload {
    /// HTML markup (from web pages, Google Docs, Notion, etc.).
    case html(String)
    /// RTF or RTFD data (from TextEdit, Notes, Mail).
    case rtf(Data)
    /// A raster image on the pasteboard (screenshots, copied images).
    case image(NSImage)
    /// One or more file URLs copied in Finder.
    case files([URL])
    /// Plain text with no richer representation available.
    case plainText(String)
    /// Nothing convertible was found.
    case empty

    var isEmpty: Bool {
        if case .empty = self { return true }
        return false
    }
}
