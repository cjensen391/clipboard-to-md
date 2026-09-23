import SwiftUI
import AppKit

@main
struct ClipboardToMarkdownApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()
    @StateObject private var prefs = Preferences.shared

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: model)
        } label: {
            Image(systemName: model.iconState.systemImage)
        }
        .menuBarExtraStyle(.menu)
        .onChange(of: appDelegate.didFinishLaunching) { _, launched in
            if launched { model.start() }
        }

        Settings {
            SettingsView(prefs: prefs)
        }
    }
}

/// The menu-bar dropdown. Rebuilt each time it's shown so the "Detected:" line
/// and "Last saved" row are always current (ux-adhd §1).
private struct MenuContent: View {
    @ObservedObject var model: AppModel

    var body: some View {
        let detected = model.detectedTypeLabel()

        Button("Save Clipboard as Markdown…") { model.saveClipboard() }
            .keyboardShortcut("m", modifiers: [.control, .option, .command])
            .disabled(detected == nil)

        if let detected {
            Text("Detected: \(detected)")
        } else {
            Text("Nothing to convert")
        }

        Button("Copy as Markdown") { model.copyAsMarkdown() }
            .disabled(detected == nil)

        Divider()

        if let last = model.lastSaved {
            Text("Last saved: \(last.url.lastPathComponent) (\(relativeTime(last.date)))")
            Button("Reveal in Finder") { model.revealLastSaved() }
            Divider()
        }

        SettingsLink {
            Text("Settings…")
        }
        .keyboardShortcut(",", modifiers: .command)

        Button("Quit Clipboard to Markdown") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

/// Runs the app as a menu-bar accessory (no dock icon) and signals readiness.
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    @Published var didFinishLaunching = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        didFinishLaunching = true
    }
}
