# clip2md

Convert the current macOS clipboard contents to Markdown on stdout.

- **Image on the clipboard** (screenshot, copied picture) → text is extracted with the
  built-in macOS **Vision** OCR engine — the same one behind Live Text. Fully offline,
  no third-party dependencies, no network.
- **RTF / HTML on the clipboard** → flattened to plain text.
- **Plain text** → passed through unchanged.

## Build

```sh
swift build -c release
```

The binary lands at `.build/release/clip2md`.

## Install

```sh
./install.sh          # copies the release binary to ~/.local/bin/clip2md
```

Make sure `~/.local/bin` is on your `PATH`.

## Usage

```sh
clip2md                       # clipboard → Markdown on stdout
clip2md > notes.md            # save it
clip2md | pbcopy              # OCR an image, put the text back on the clipboard

clip2md -l en-US,fr-FR        # OCR language hints
clip2md --fast                # faster, lower-accuracy OCR
clip2md --no-correction       # disable spelling correction
clip2md --list-languages      # list supported OCR languages
clip2md --help
```

Exit code `3` means the clipboard held nothing convertible.

## Notes

Vision OCR recognizes text line-by-line, top-to-bottom. It does **not** reconstruct
tables or multi-column layouts — output is the reading order Vision infers from each
text region's position.

Requires macOS 12 or newer.
