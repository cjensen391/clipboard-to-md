import AppKit
import UniformTypeIdentifiers

/// Writes a `MarkdownResult` to disk — either via an NSSavePanel ("ask each
/// time") or straight into a folder ("always this folder"). Sidecar images are
/// written next to the `.md` using the same names referenced in the markdown.
@MainActor
struct MarkdownWriter {

    enum WriteError: LocalizedError {
        case cancelled
        case noWritableFolder
        var errorDescription: String? {
            switch self {
            case .cancelled: return "Save cancelled."
            case .noWritableFolder: return "Couldn't find a folder to save into."
            }
        }
    }

    /// Outcome of a successful write.
    struct Written {
        let url: URL
        let sidecarCount: Int
        var folder: URL { url.deletingLastPathComponent() }
    }

    /// A markdown type, falling back to plain text on older systems.
    private var markdownType: UTType {
        UTType(filenameExtension: "md") ?? .plainText
    }

    // MARK: - Save panel path ("ask each time")

    /// Show a save panel (pre-filled + pre-selected filename, opening to the
    /// remembered folder) and write on confirm. Returns `nil` if the user picked
    /// the "Copy Markdown instead" escape hatch (caller performs the copy).
    func presentSavePanel(for result: MarkdownResult,
                          startingFolder: URL,
                          onCopyInstead: @escaping () -> Void) throws -> Written? {
        // Accessory apps open panels behind the frontmost app unless we activate
        // first (ux-hig). This makes Return-to-save work without a click.
        NSApp.activate(ignoringOtherApps: true)

        let panel = NSSavePanel()
        panel.allowedContentTypes = [markdownType]
        panel.nameFieldStringValue = "\(result.suggestedName).md"
        panel.directoryURL = startingFolder
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.title = "Save Clipboard as Markdown"
        panel.prompt = "Save"

        var copyInsteadChosen = false
        panel.accessoryView = makeAccessoryView(copyInstead: {
            copyInsteadChosen = true
            panel.cancel(nil)
        })

        // Run from an accessory app with no host window, the panel otherwise
        // opens at the screen origin (bottom-left). Center it before it's shown.
        panel.makeKeyAndOrderFront(nil)
        panel.center()
        let response = panel.runModal()

        if copyInsteadChosen {
            onCopyInstead()
            return nil
        }
        guard response == .OK, let url = panel.url else {
            throw WriteError.cancelled
        }

        try write(result, to: url)
        return Written(url: url, sidecarCount: result.sidecars.count)
    }

    // MARK: - Direct path ("always this folder")

    /// Write straight into `folder`, auto-incrementing on collision (never a
    /// destructive overwrite — ux-adhd §3).
    func writeDirect(_ result: MarkdownResult, to folder: URL) throws -> Written {
        let needsScope = folder.startAccessingSecurityScopedResource()
        defer { if needsScope { folder.stopAccessingSecurityScopedResource() } }

        let url = nonCollidingURL(base: result.suggestedName, in: folder)
        try write(result, to: url)
        return Written(url: url, sidecarCount: result.sidecars.count)
    }

    // MARK: - Shared write

    private func write(_ result: MarkdownResult, to url: URL) throws {
        try result.markdown.write(to: url, atomically: true, encoding: .utf8)
        let dir = url.deletingLastPathComponent()
        for sidecar in result.sidecars {
            let sidecarURL = dir.appendingPathComponent(sidecar.name)
            try sidecar.data.write(to: sidecarURL, options: .atomic)
        }
    }

    /// `Name.md`, then `Name 2.md`, `Name 3.md`, … if taken.
    private func nonCollidingURL(base: String, in folder: URL) -> URL {
        let fm = FileManager.default
        var candidate = folder.appendingPathComponent("\(base).md")
        var n = 2
        while fm.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent("\(base) \(n).md")
            n += 1
        }
        return candidate
    }

    /// A one-row accessory view: the "Copy Markdown instead" escape hatch.
    private func makeAccessoryView(copyInstead: @escaping () -> Void) -> NSView {
        let handler = ButtonHandler(action: copyInstead)
        let container = AccessoryContainer(frame: NSRect(x: 0, y: 0, width: 460, height: 48))
        container.handler = handler // retained by the view for the panel's lifetime

        let button = NSButton(title: "Copy Markdown instead", target: nil, action: nil)
        button.bezelStyle = .rounded
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setButtonType(.momentaryPushIn)

        button.target = handler
        button.action = #selector(ButtonHandler.fire)

        let caption = NSTextField(labelWithString: "Puts the Markdown on your clipboard, no file saved.")
        caption.font = .systemFont(ofSize: 11)
        caption.textColor = .secondaryLabelColor
        caption.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(button)
        container.addSubview(caption)
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            button.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            caption.leadingAnchor.constraint(equalTo: button.trailingAnchor, constant: 12),
            caption.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            caption.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -20)
        ])
        return container
    }
}

/// Bridges an AppKit target/action to a Swift closure for the accessory button.
private final class ButtonHandler: NSObject {
    let action: () -> Void
    init(action: @escaping () -> Void) { self.action = action }
    @objc func fire() { action() }
}

/// An accessory view that keeps its `ButtonHandler` alive — NSButton's `target`
/// is weak, so something in the view hierarchy must retain it.
private final class AccessoryContainer: NSView {
    var handler: ButtonHandler?
}
