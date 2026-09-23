#!/bin/bash
# Builds Clipboard to Markdown.app — a self-contained menu-bar bundle.
#
#   ./build-app.sh                 release build → build/Clipboard to Markdown.app
#   ./build-app.sh --debug         faster debug build
#   ./build-app.sh --sign "ID"     codesign with a Developer ID / Apple Development identity
#
# No external binaries are downloaded; the JS converter assets ship from Resources/.
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="Clipboard to Markdown"
EXECUTABLE="ClipboardToMarkdown"
VERSION="1.0.0"
BUILD_NUM="$(date +%Y%m%d%H%M 2>/dev/null || echo 1)"
CONFIG="release"
SIGN_IDENTITY=""

while [[ $# -gt 0 ]]; do
	case "$1" in
		--debug) CONFIG="debug"; shift ;;
		--sign)  SIGN_IDENTITY="${2:-}"; shift 2 ;;
		*) echo "Unknown option: $1" >&2; exit 2 ;;
	esac
done

OUT_DIR="build"
APP_DIR="$OUT_DIR/$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RES="$CONTENTS/Resources"

echo "==> Building ($CONFIG)…"
swift build -c "$CONFIG"
BIN_PATH="$(swift build -c "$CONFIG" --show-bin-path)"

echo "==> Assembling bundle…"
rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RES"

cp "$BIN_PATH/$EXECUTABLE" "$MACOS/$EXECUTABLE"

# Converter assets — HTML + all three JS files it loads (CSP script-src 'self').
for asset in converter.html turndown.js turndown-plugin-gfm.js converter-setup.js; do
	cp "Resources/$asset" "$RES/$asset"
done

echo "==> Generating app icon…"
ICONSET="$OUT_DIR/AppIcon.iconset"
rm -rf "$ICONSET"
if swift Packaging/make-icon.swift "$ICONSET" >/dev/null 2>&1 && command -v iconutil >/dev/null; then
	iconutil -c icns "$ICONSET" -o "$RES/AppIcon.icns"
	rm -rf "$ICONSET"
else
	echo "    (icon generation skipped — app will use a default icon)"
fi

echo "==> Writing Info.plist…"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD_NUM/" \
	Packaging/Info.plist.template > "$CONTENTS/Info.plist"
printf 'APPL????' > "$CONTENTS/PkgInfo"

if [[ -n "$SIGN_IDENTITY" ]]; then
	echo "==> Codesigning as: $SIGN_IDENTITY"
	codesign --force --deep --options runtime \
		--sign "$SIGN_IDENTITY" "$APP_DIR"
	codesign --verify --deep --strict "$APP_DIR" && echo "    signature verified"
else
	# Ad-hoc sign so notifications/hotkeys behave more predictably in local runs.
	echo "==> Ad-hoc signing (unsigned distribution)…"
	codesign --force --deep --sign - "$APP_DIR" || true
fi

echo "==> Done: $APP_DIR"
