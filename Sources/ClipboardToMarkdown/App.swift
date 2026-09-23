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

    /// Strong ref — `NSApp.servicesProvider` is weak, so we must hold it.
    private let serviceProvider = ServiceProvider()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Register the macOS Service so "Save Clipboard as Markdown" appears in
        // the right-click / Services menu of every app, working on the current
        // selection. `NSUpdateDynamicServices` refreshes the system's cache so
        // it shows up without a re-login after an install.
        NSApp.servicesProvider = serviceProvider
        NSUpdateDynamicServices()

        didFinishLaunching = true
    }

    /// A menu-bar app has no Dock icon or window to re-open, so a "reopen" only
    /// arrives when something `open`s the already-running app — Spotlight hitting
    /// Return, or an Automator / Shortcuts launcher. Treat that as "save now", so
    /// ⌘Space + a few keystrokes + Return runs the whole convert-and-save flow.
    /// (First launch fires `didFinishLaunching`, not this, so it never fires here.)
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        MainActor.assumeIsolated {
            AppModel.shared?.saveClipboard()
        }
        return true
    }
}

/// Vends the macOS Service. The selected content arrives on the service
/// pasteboard (not the general clipboard), so we hand that pasteboard straight
/// to the save flow — letting the user convert a selection from any app without
/// copying first. Declared in Info.plist under `NSServices`.
final class ServiceProvider: NSObject {
    @objc func saveSelectionAsMarkdown(_ pboard: NSPasteboard,
                                       userData: String?,
                                       error: AutoreleasingUnsafeMutablePointer<NSString>?) {
        // Services are delivered on the main thread, but the pasteboard is a
        // non-Sendable, task-isolated value — pass its name (a plain string)
        // across the actor hop and re-acquire the pasteboard on the main actor.
        let name = pboard.name
        MainActor.assumeIsolated {
            AppModel.shared?.saveSelection(from: NSPasteboard(name: name))
        }
    }
}
