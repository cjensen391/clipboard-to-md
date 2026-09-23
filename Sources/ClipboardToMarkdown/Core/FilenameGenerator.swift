import Foundation

/// Derives a safe, human-friendly base filename (no extension) from markdown.
///
/// Strategy: first `# H1` → slug; else first non-empty line → slug;
/// else a timestamped fallback.
struct FilenameGenerator {

    /// Characters illegal in HFS+/APFS names plus a few that break shells/URLs.
    private static let illegal = CharacterSet(charactersIn: "/\\:\0*?\"<>|")
    private static let maxLength = 80

    /// `now` is injectable for deterministic tests.
    func suggestedName(for markdown: String, now: Date = Date()) -> String {
        if let heading = firstHeading(in: markdown), let slug = slug(heading) {
            return slug
        }
        if let line = firstNonEmptyLine(in: markdown), let slug = slug(line) {
            return slug
        }
        return timestampName(now)
    }

    private func firstHeading(in markdown: String) -> String? {
        for rawLine in markdown.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("#") {
                let text = line.drop(while: { $0 == "#" })
                    .trimmingCharacters(in: .whitespaces)
                if !text.isEmpty { return text }
            }
        }
        return nil
    }

    private func firstNonEmptyLine(in markdown: String) -> String? {
        for rawLine in markdown.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if !line.isEmpty { return line }
        }
        return nil
    }

    /// Sanitize into a filename: strip illegal chars, collapse whitespace to
    /// single spaces, trim, and cap length. Returns nil if nothing usable left.
    private func slug(_ text: String) -> String? {
        // Strip common inline-markdown punctuation so headings read cleanly.
        let stripped = text.replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "`", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "#", with: "")

        let cleanedScalars = stripped.unicodeScalars.map { scalar -> Character in
            Self.illegal.contains(scalar) ? " " : Character(scalar)
        }
        let collapsed = String(cleanedScalars)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        let trimmed = collapsed.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(Self.maxLength)).trimmingCharacters(in: .whitespaces)
    }

    private func timestampName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "Clipboard-\(formatter.string(from: date))"
    }
}
