#!/bin/bash
# Build clip2md (release) and install it to ~/.local/bin.
set -euo pipefail

cd "$(dirname "$0")"
swift build -c release

dest="${1:-$HOME/.local/bin}"
mkdir -p "$dest"
cp -f .build/release/clip2md "$dest/clip2md"
echo "Installed clip2md -> $dest/clip2md"

case ":$PATH:" in
  *":$dest:"*) ;;
  *) echo "Note: $dest is not on your PATH." ;;
esac
