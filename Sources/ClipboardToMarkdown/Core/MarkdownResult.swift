import Foundation

/// A sidecar asset (e.g. a PNG) that must be written alongside the `.md`.
struct Sidecar: Equatable {
    /// Filename relative to the `.md`, matching the reference used in the markdown.
    let name: String
    let data: Data
}

/// The output of the conversion pipeline: markdown text, a suggested filename
/// (sans extension), and any sidecar files to write into the same directory.
struct MarkdownResult: Equatable {
    let markdown: String
    /// Suggested base filename without the `.md` extension.
    let suggestedName: String
    let sidecars: [Sidecar]

    init(markdown: String, suggestedName: String, sidecars: [Sidecar] = []) {
        self.markdown = markdown
        self.suggestedName = suggestedName
        self.sidecars = sidecars
    }
}
