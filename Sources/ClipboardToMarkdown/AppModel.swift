import AppKit
import SwiftUI
import KeyboardShortcuts

/// The menu-bar icon's visible state — the app's only always-on status channel
/// (ux-adhd §1).
enum IconState {
    case idle
    case working
    case success
    case attention

    var systemImage: String {
        switch self {
        case .idle:      return "doc.richtext"
        case .working:   return "doc.richtext.fill"
        case .success:   return "checkmark.circle.fill"
        case .attention: return "exclamationmark.circle"
        }
    }
}

/// A record of the most recent successful save, for the "Last saved" menu row.
struct LastSaved {
    let url: URL
    let date: Date
    let sidecarCount: Int
}

/// Owns the warmed conversion pipeline and drives every user-facing outcome:
/// icon state, HUD toasts, notifications, and the save flow. `@MainActor`
/// throughout — all of AppKit/WebKit lives here.
@MainActor
final class AppModel: ObservableObject {

    @Published private(set) var iconState: IconState = .idle
    @Published private(set) var lastSaved: LastSaved?

    private let prefs: Preferences
    private let engine: TurndownEngine
    private let conversion: ConversionService
    private let reader = PasteboardReader()
    private let writer = MarkdownWriter()
    private let notifier = Notifier()

    /// Held converted markdown that failed to write — never dropped, so a retry
    /// needs no re-copy (ux-adhd §6, "never lose the converted Markdown").
    private var pendingResult: MarkdownResult?

    private var iconResetTask: Task<Void, Never>?

    init(prefs: Preferences = .shared) {
        self.prefs = prefs
        self.engine = TurndownEngine()
        self.conversion = ConversionService(engine: engine)
    }

    /// Warm the WebView and register the global hotkey. Call once at launch.
    func start() {
        conversion.warmUp()
        notifier.requestAuthorizationIfNeeded()
        KeyboardShortcuts.onKeyUp(for: .saveClipboardAsMarkdown) { [weak self] in
            self?.saveClipboard()
        }
    }

    // MARK: - Detection (for the menu's "Detected:" caption)

    /// A human label for what's currently on the clipboard, or nil if empty.
    func detectedTypeLabel() -> String? {
        switch reader.read() {
        case .html:      return "Rich text (HTML)"
        case .rtf:       return "Rich text"
        case .image:     return "Image"
        case .files(let urls):
            return urls.count == 1 ? "File" : "\(urls.count) files"
        case .plainText: return "Plain text"
        case .empty:     return nil
        }
    }

    var hasConvertibleClipboard: Bool { detectedTypeLabel() != nil }

    // MARK: - Primary action

    /// The hotkey / menu primary action. Flashes the icon immediately so the
    /// keypress is always acknowledged, then converts and saves.
    func saveClipboard() {
        flashWorking()
        Task { await self.performSave() }
    }

    private func performSave() async {
        let payload = reader.read()
        if payload.isEmpty {
            reportEmpty()
            return
        }

        let result: MarkdownResult
        do {
            result = try await conversion.convert(payload)
        } catch {
            reportConversionFailure(payload)
            return
        }

        do {
            let written: MarkdownWriter.Written?
            switch prefs.savePolicy {
            case .askEachTime:
                written = try writer.presentSavePanel(
                    for: result,
                    startingFolder: prefs.lastFolder,
                    onCopyInstead: { [weak self] in self?.copy(result) }
                )
            case .alwaysFolder:
                guard let folder = prefs.defaultFolder else {
                    // Misconfigured: fall back to asking rather than failing.
                    written = try writer.presentSavePanel(
                        for: result,
                        startingFolder: prefs.lastFolder,
                        onCopyInstead: { [weak self] in self?.copy(result) }
                    )
                    break
                }
                written = try writer.writeDirect(result, to: folder)
            }

            guard let written else { return } // copy-instead already handled
            didWrite(written, result: result)

        } catch MarkdownWriter.WriteError.cancelled {
            setIcon(.idle) // user backed out — a non-event
        } catch {
            reportWriteFailure(result, error: error)
        }
    }

    // MARK: - Copy as Markdown

    func copyAsMarkdown() {
        flashWorking()
        Task {
            let payload = reader.read()
            if payload.isEmpty { reportEmpty(); return }
            do {
                let result = try await conversion.convert(payload)
                copy(result)
            } catch {
                reportConversionFailure(payload)
            }
        }
    }

    private func copy(_ result: MarkdownResult) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(result.markdown, forType: .string)
        setIcon(.success)
        scheduleIdle()
        toastSuccess(title: "Copied as Markdown", subtitle: "On your clipboard, no file saved.")
    }

    // MARK: - Outcomes

    private func didWrite(_ written: MarkdownWriter.Written, result: MarkdownResult) {
        pendingResult = nil
        prefs.rememberLastFolder(written.folder)
        lastSaved = LastSaved(url: written.url, date: Date(),
                              sidecarCount: written.sidecarCount)
        setIcon(.success)
        scheduleIdle()

        let name = written.url.lastPathComponent
        let folder = written.folder
        var subtitle = prettyFolder(folder)
        if written.sidecarCount > 0 {
            let imgs = written.sidecarCount == 1 ? "1 image" : "\(written.sidecarCount) images"
            subtitle = "+ \(imgs) · \(subtitle)"
        }
        toastSuccess(title: "Saved \(name)", subtitle: subtitle, reveal: written.url)
        notifier.notifySaved(name: name, at: written.url)
    }

    private func reportEmpty() {
        // Empty is a non-event, not a failure: neutral toast, no icon dot, no sound.
        setIcon(.idle)
        HUDToast.shared.show(
            style: .neutral,
            title: "Nothing to convert",
            subtitle: "The clipboard is empty — copy some text or an image.",
            duration: 4.0
        )
    }

    private func reportConversionFailure(_ payload: ClipboardPayload) {
        // Fail soft: fall back to plain text so the user is never empty-handed.
        if let plain = plainTextFallback(payload) {
            let result = MarkdownResult(markdown: plain,
                                        suggestedName: FilenameGenerator().suggestedName(for: plain))
            copy(result)
            HUDToast.shared.show(
                style: .neutral,
                title: "Copied as plain text",
                subtitle: "This clipboard was an unusual format, so formatting was simplified.",
                duration: 4.0
            )
            return
        }
        setIcon(.attention)
        HUDToast.shared.show(
            style: .error,
            title: "Couldn't convert this clipboard",
            subtitle: "It may be an unusual format.",
            duration: 5.0
        )
    }

    private func reportWriteFailure(_ result: MarkdownResult, error: Error) {
        pendingResult = result
        setIcon(.attention)
        HUDToast.shared.show(
            style: .error,
            title: "Couldn't save there",
            subtitle: "Your Markdown is safe — pick another folder.",
            duration: 8.0,
            action: ToastAction(title: "Choose Folder…") { [weak self] in
                self?.retryPending()
            }
        )
    }

    /// Retry a held-in-memory result via a fresh save panel at Documents.
    private func retryPending() {
        guard let result = pendingResult else { return }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        do {
            let written = try writer.presentSavePanel(
                for: result,
                startingFolder: docs,
                onCopyInstead: { [weak self] in self?.copy(result) }
            )
            if let written { didWrite(written, result: result) }
        } catch MarkdownWriter.WriteError.cancelled {
            setIcon(.idle)
        } catch {
            reportWriteFailure(result, error: error)
        }
    }

    // MARK: - Menu helpers

    func revealLastSaved() {
        guard let url = lastSaved?.url else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    // MARK: - Icon state machine

    private func flashWorking() {
        setIcon(.working)
    }

    private func setIcon(_ state: IconState) {
        iconResetTask?.cancel()
        iconState = state
    }

    /// Return to idle after the success glyph has had time to register.
    private func scheduleIdle() {
        iconResetTask?.cancel()
        iconResetTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled else { return }
            self?.iconState = .idle
        }
    }

    private func toastSuccess(title: String, subtitle: String?, reveal: URL? = nil) {
        guard prefs.showConfirmation else {
            if prefs.playSound { playTick() }
            return
        }
        HUDToast.shared.show(
            style: .success,
            title: title,
            subtitle: subtitle,
            duration: 3.0,
            onClick: reveal.map { url in { NSWorkspace.shared.activateFileViewerSelecting([url]) } }
        )
        if prefs.playSound { playTick() }
    }

    private func playTick() {
        NSSound(named: "Tink")?.play()
    }

    // MARK: - Fallbacks / formatting

    private func plainTextFallback(_ payload: ClipboardPayload) -> String? {
        switch payload {
        case .plainText(let t): return t
        case .html, .rtf:
            return NSPasteboard.general.string(forType: .string)
        default:
            return nil
        }
    }

    private func prettyFolder(_ url: URL) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = url.path
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }
}
