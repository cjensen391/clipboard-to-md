import Foundation

/// Locates bundled JS/HTML resources. In a packaged `.app` they live in
/// `Contents/Resources` (found via `Bundle.main`). During `swift run` dev
/// sessions there is no bundle copy, so we fall back to the repo's
/// `Resources/` directory resolved from this file's compile-time path.
enum ResourceLocator {
    enum ResourceError: LocalizedError {
        case notFound(String)
        var errorDescription: String? {
            switch self {
            case .notFound(let name): return "Bundled resource not found: \(name)"
            }
        }
    }

    /// URL of the converter HTML that hosts Turndown.
    static func converterHTML() throws -> URL {
        try url(forResource: "converter", withExtension: "html")
    }

    static func url(forResource name: String, withExtension ext: String) throws -> URL {
        if let bundled = Bundle.main.url(forResource: name, withExtension: ext) {
            return bundled
        }
        // Dev fallback: <repo>/Resources/<name>.<ext>, derived from this source file.
        let devURL = devResourcesDirectory().appendingPathComponent("\(name).\(ext)")
        if FileManager.default.fileExists(atPath: devURL.path) {
            return devURL
        }
        throw ResourceError.notFound("\(name).\(ext)")
    }

    /// <repo>/Resources — this file is Sources/ClipboardToMarkdown/Core/ResourceLocator.swift,
    /// so four parents up is the repo root.
    private static func devResourcesDirectory() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Core
            .deletingLastPathComponent() // ClipboardToMarkdown
            .deletingLastPathComponent() // Sources
            .deletingLastPathComponent() // repo root
            .appendingPathComponent("Resources")
    }
}
