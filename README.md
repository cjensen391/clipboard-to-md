# Clipboard to Markdown

A native macOS menu-bar app that turns whatever is on your clipboard into a
Markdown (`.md`) file — one keystroke, one confirmation, done.

Copy a rich-text selection from a webpage, a Word doc, a Slack message, an
image, or a set of files. Press the hotkey. A save panel appears with a smart
filename already filled in. Press **Return**. You have a clean Markdown file.

## Features

- **Menu-bar only** — no Dock icon, no window clutter. The menu-bar glyph is the
  whole UI, and it changes to show working / success / needs-attention state.
- **Global hotkey** — ⌃⌥⌘M by default, remappable in Settings.
- **Smart conversion**
  - Rich text / HTML → GitHub-Flavored Markdown (tables, strikethrough, task
    lists) via [Turndown](https://github.com/mixmark-io/turndown) running in a
    sandboxed, offline `WKWebView`.
  - Images → a sidecar `.png` next to the `.md`, embedded with `![](name.png)`.
  - Copied files → a Markdown link list.
  - Plain text → passed through verbatim.
- **Smart filename** — derived from the first heading or first line, sanitized.
- **Save your way** — "ask each time" (default) with a pre-filled, pre-selected
  filename, or "always this folder" for zero-friction saves.
- **Never destructive** — filename collisions auto-increment (`Notes 2.md`),
  never overwrite.
- **Never lose your Markdown** — if a write fails, the converted Markdown is held
  in memory so you can retry into another folder, or copy it instead.

## Requirements

- macOS 14 (Sonoma) or later
- Xcode / Swift toolchain (Swift 6) to build

## Build & install

```sh
./install.sh
```

This builds a release `.app`, copies it to `/Applications`, and launches it.
Look for the document icon in your menu bar.

To build without installing:

```sh
./build-app.sh            # → build/Clipboard to Markdown.app
./build-app.sh --debug    # faster debug build
./build-app.sh --sign "Developer ID Application: Your Name (TEAMID)"
```

## Usage

1. Copy anything (text, rich text, an image, or files).
2. Press **⌃⌥⌘M** — or click the menu-bar icon and choose **Save Clipboard as
   Markdown…**.
3. Confirm the filename and folder, press **Return**.

The menu also offers **Copy as Markdown** (no file, just puts the Markdown back
on your clipboard) and a **Last saved** row with **Reveal in Finder**.

### Launch from Spotlight (⌘Space)

Prefer Spotlight to a hotkey? Build the companion launcher:

```sh
./make-launcher.sh                       # → "Save Clipboard as Markdown.app" in /Applications
./make-launcher.sh "Grab Markdown"       # …or give it your own (shorter) name
```

It's a tiny app that tells the running menu-bar app to convert-and-save. Trigger
it with **⌘Space → type a few letters of its name → Return**. The app's name is
whatever you pass (or rename the `.app` in Finder), so pick something that types
fast. First run shows a one-time "wants to control Clipboard to Markdown"
permission prompt — click OK.

Under the hood the menu-bar app treats a re-open (an external `open`, whether
from this launcher, Spotlight, Automator, or Shortcuts) as "save now."

Open **Settings…** (⌘,) to change the hotkey, choose ask-vs-fixed-folder saving,
toggle the success sound / confirmation popup, and enable **Launch at login**.

## How it works / privacy

Everything runs locally. The HTML→Markdown step happens in a headless
`WKWebView` with a strict Content-Security-Policy (`default-src 'none';
script-src 'self'`), a non-persistent data store, and no network or navigation.
No clipboard content ever leaves your machine. No external binaries are
downloaded at build time — the JavaScript converter assets ship in `Resources/`.

## Project layout

```
Sources/ClipboardToMarkdown/
  App.swift              MenuBarExtra + Settings scenes, accessory-app delegate
  AppModel.swift         Orchestrates convert → save → feedback; icon state
  Core/                  Conversion pipeline, pasteboard reading, file writing
  Support/               Preferences, hotkey name, notifications
  UI/                    HUD toast, Settings screen
Resources/               converter.html + turndown*.js (bundled at build time)
Packaging/               Info.plist template + icon generator
Tests/                   Filename + conversion unit tests
```

## Notes on signing

An unsigned/ad-hoc build runs fine, but macOS user notifications only deliver
from a properly code-signed app. Global hotkeys, saving, and the HUD toast work
regardless. Pass `--sign` to `build-app.sh` with a Developer ID (or Apple
Development) identity to enable notification delivery.
