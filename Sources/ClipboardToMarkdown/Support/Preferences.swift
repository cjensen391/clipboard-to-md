import Foundation
import AppKit
import ServiceManagement

/// Where a converted file goes.
enum SavePolicy: String {
    /// Show an NSSavePanel every time (default — the spec's "confirmation, not composition").
    case askEachTime
    /// Write straight to `defaultFolder` with the auto filename, then toast + Undo.
    case alwaysFolder
}

/// User-facing settings, backed by `UserDefaults`. `@MainActor` because it
/// touches AppKit (login items, folder bookmarks) and drives SwiftUI.
///
/// Every property has a working default so the app is fully usable without ever
/// opening Settings (ux-adhd §5).
@MainActor
final class Preferences: ObservableObject {

    static let shared = Preferences()

    private let defaults: UserDefaults

    private enum Key {
        static let savePolicy = "savePolicy"
        static let defaultFolderBookmark = "defaultFolderBookmark"
        static let lastFolderBookmark = "lastFolderBookmark"
        static let playSound = "playSound"
        static let showConfirmation = "showConfirmation"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.savePolicy = SavePolicy(rawValue: defaults.string(forKey: Key.savePolicy) ?? "")
            ?? .askEachTime
        // Feedback defaults are ON (spec §5). `object(forKey:)` distinguishes
        // "unset" (→ default on) from an explicit false.
        self.playSound = (defaults.object(forKey: Key.playSound) as? Bool) ?? true
        self.showConfirmation = (defaults.object(forKey: Key.showConfirmation) as? Bool) ?? true
        self.defaultFolder = Self.resolveBookmark(defaults.data(forKey: Key.defaultFolderBookmark))
    }

    @Published var savePolicy: SavePolicy {
        didSet { defaults.set(savePolicy.rawValue, forKey: Key.savePolicy) }
    }

    @Published var playSound: Bool {
        didSet { defaults.set(playSound, forKey: Key.playSound) }
    }

    @Published var showConfirmation: Bool {
        didSet { defaults.set(showConfirmation, forKey: Key.showConfirmation) }
    }

    /// The configured "always save here" folder (security-scoped).
    @Published private(set) var defaultFolder: URL?

    func setDefaultFolder(_ url: URL?) {
        defaultFolder = url
        guard let url else {
            defaults.removeObject(forKey: Key.defaultFolderBookmark)
            return
        }
        if let data = try? url.bookmarkData(options: .withSecurityScope,
                                            includingResourceValuesForKeys: nil,
                                            relativeTo: nil) {
            defaults.set(data, forKey: Key.defaultFolderBookmark)
        }
    }

    // MARK: - Last-used folder (remembered across launches for the save panel)

    /// The directory the save panel should open to: last-used, else default, else Documents.
    var lastFolder: URL {
        if let remembered = Self.resolveBookmark(defaults.data(forKey: Key.lastFolderBookmark)),
           FileManager.default.fileExists(atPath: remembered.path) {
            return remembered
        }
        if let def = defaultFolder, FileManager.default.fileExists(atPath: def.path) {
            return def
        }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
    }

    func rememberLastFolder(_ url: URL) {
        if let data = try? url.bookmarkData(options: .withSecurityScope,
                                            includingResourceValuesForKeys: nil,
                                            relativeTo: nil) {
            defaults.set(data, forKey: Key.lastFolderBookmark)
        }
    }

    // MARK: - Launch at login

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
                objectWillChange.send()
            } catch {
                NSLog("Launch-at-login toggle failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Reset

    func resetToDefaults() {
        savePolicy = .askEachTime
        playSound = true
        showConfirmation = true
        setDefaultFolder(nil)
        KeyboardShortcutsReset.resetSaveShortcut()
    }

    private static func resolveBookmark(_ data: Data?) -> URL? {
        guard let data else { return nil }
        var stale = false
        let url = try? URL(resolvingBookmarkData: data,
                           options: .withSecurityScope,
                           relativeTo: nil,
                           bookmarkDataIsStale: &stale)
        return url
    }
}
