import KeyboardShortcuts

/// The single global shortcut for the app. Carbon-based (no Accessibility
/// prompt). Default ⌃⌥⌘M — recoverable from Settings if the user breaks it.
extension KeyboardShortcuts.Name {
    static let saveClipboardAsMarkdown = Self(
        "saveClipboardAsMarkdown",
        default: .init(.m, modifiers: [.control, .option, .command])
    )
}

/// Recovery affordance (ux-adhd §5/§6): restore the default ⌃⌥⌘M shortcut so a
/// user who breaks their global hotkey is never left with a dead end.
enum KeyboardShortcutsReset {
    static func resetSaveShortcut() {
        KeyboardShortcuts.reset(.saveClipboardAsMarkdown)
    }
}
