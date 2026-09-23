#!/bin/bash
# Builds a tiny Spotlight-launchable app that triggers "Save Clipboard as
# Markdown" in the running menu-bar app. This is the Automator / Shortcuts
# equivalent — an app you invoke with ⌘Space + a few keystrokes + Return —
# but self-contained (no Automator document, nothing to break across macOS
# versions). It sends the target app a "reopen" event, which the menu-bar app
# handles by running the whole convert-and-save flow.
#
#   ./make-launcher.sh ["Launcher Name"]
#
# Default name: "Save Clipboard as Markdown". Rename the resulting .app freely —
# its name is what you type into Spotlight. Installs to /Applications.
#
# First run pops a one-time macOS permission prompt ("… wants to control
# Clipboard to Markdown") — click OK. After that it's silent.
set -euo pipefail

cd "$(dirname "$0")"

LAUNCHER_NAME="${1:-Save Clipboard as Markdown}"
TARGET_APP="Clipboard to Markdown"
OUT="build/$LAUNCHER_NAME.app"
DEST="/Applications/$LAUNCHER_NAME.app"

mkdir -p build
rm -rf "$OUT"

echo "==> Compiling launcher: $LAUNCHER_NAME"
osacompile \
	-e "tell application \"$TARGET_APP\" to launch" \
	-e "tell application \"$TARGET_APP\" to reopen" \
	-o "$OUT"

echo "==> Installing to $DEST"
rm -rf "$DEST"
cp -R "$OUT" "$DEST"

echo "==> Done."
echo "    Trigger it with: ⌘Space, type \"$LAUNCHER_NAME\" (a few letters is enough), Return."
echo "    First run asks permission to control \"$TARGET_APP\" — click OK once."
