#!/bin/bash
# Builds (if needed) and installs Clipboard to Markdown.app into /Applications,
# then launches it. Spotlight will find it as "Clipboard to Markdown".
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="Clipboard to Markdown"
APP_DIR="build/$APP_NAME.app"
DEST="/Applications/$APP_NAME.app"

# Always rebuild the bundle so an install never ships a stale binary.
echo "==> Building app bundle…"
./build-app.sh

echo "==> Installing to $DEST"
if [[ -d "$DEST" ]]; then
	# Quit a running copy so the replace doesn't fail on a busy binary.
	osascript -e 'quit app "Clipboard to Markdown"' >/dev/null 2>&1 || true
	sleep 1
	rm -rf "$DEST"
fi
cp -R "$APP_DIR" "$DEST"

echo "==> Launching…"
open "$DEST"

echo "==> Installed. Look for the document icon in your menu bar."
echo "    Default hotkey: ⌃⌥⌘M (Control-Option-Command-M)"
