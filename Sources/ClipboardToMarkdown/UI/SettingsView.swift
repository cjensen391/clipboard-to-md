import SwiftUI
import AppKit
import KeyboardShortcuts

/// Single scannable settings screen (ux-adhd §5). Every control has a working
/// default, so the app is fully usable without ever opening this window.
struct SettingsView: View {

    @ObservedObject var prefs: Preferences

    var body: some View {
        Form {
            Section("Shortcut") {
                LabeledContent("Global hotkey") {
                    KeyboardShortcuts.Recorder(for: .saveClipboardAsMarkdown)
                }
                Button("Reset to ⌃⌥⌘M") {
                    KeyboardShortcutsReset.resetSaveShortcut()
                }
                .buttonStyle(.link)
                .font(.footnote)
            }

            Section("Saving") {
                Picker("Save to", selection: $prefs.savePolicy) {
                    Text("Ask me each time").tag(SavePolicy.askEachTime)
                    Text("Always this folder").tag(SavePolicy.alwaysFolder)
                }
                .pickerStyle(.radioGroup)

                if prefs.savePolicy == .alwaysFolder {
                    LabeledContent("Folder") {
                        HStack {
                            Text(folderLabel)
                                .foregroundStyle(prefs.defaultFolder == nil ? .secondary : .primary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Button("Choose…", action: chooseFolder)
                        }
                    }
                }

                LabeledContent("Filename") {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Smart (heading or first line)")
                        Text("Example: “Meeting-notes.md”")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Feedback") {
                Toggle("Play a sound on success", isOn: $prefs.playSound)
                Toggle("Show confirmation popup", isOn: $prefs.showConfirmation)
            }

            Section("General") {
                Toggle("Launch at login", isOn: Binding(
                    get: { prefs.launchAtLogin },
                    set: { prefs.launchAtLogin = $0 }
                ))
            }

            Section {
                HStack {
                    Spacer()
                    Button("Reset to defaults", action: prefs.resetToDefaults)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            // Accessory apps open Settings behind the frontmost app otherwise.
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private var folderLabel: String {
        guard let url = prefs.defaultFolder else { return "No folder chosen" }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = url.path
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }

    private func chooseFolder() {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        panel.directoryURL = prefs.defaultFolder
        if panel.runModal() == .OK, let url = panel.url {
            prefs.setDefaultFolder(url)
        }
    }
}
