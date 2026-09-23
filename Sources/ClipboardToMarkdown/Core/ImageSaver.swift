import Foundation
import AppKit

/// Encodes an `NSImage` to PNG data for writing as a sidecar file.
struct ImageSaver {

    enum ImageError: LocalizedError {
        case noBitmap
        case encodeFailed
        var errorDescription: String? {
            switch self {
            case .noBitmap: return "The copied image could not be read."
            case .encodeFailed: return "The copied image could not be encoded as PNG."
            }
        }
    }

    /// Encode to PNG. Goes through the image's TIFF representation to obtain a
    /// bitmap rep, then re-encodes as PNG.
    func pngData(from image: NSImage) throws -> Data {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else {
            throw ImageError.noBitmap
        }
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            throw ImageError.encodeFailed
        }
        return png
    }
}
