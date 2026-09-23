// clip2md — read the macOS clipboard and emit Markdown.
//
// Behavior:
//   • Clipboard holds an image  → run Vision OCR, emit the recognized text.
//   • Clipboard holds RTF/HTML  → flatten to plain text.
//   • Clipboard holds plain text → pass it through.
// Output always goes to stdout as Markdown.
//
// Requires macOS 12+. Vision OCR uses the same on-device engine as Live Text: offline, no
// third-party dependencies, no network. It recognizes text line-by-line
// top-to-bottom and does not reconstruct tables or columns.

import AppKit
import Foundation
import Vision

// MARK: - Options

struct Options {
    var languages: [String] = []      // e.g. ["en-US", "fr-FR"]; empty = auto
    var fast = false                  // .fast instead of .accurate
    var noCorrection = false          // disable usesLanguageCorrection
    var listLanguages = false
    var showHelp = false
}

func parseArgs(_ argv: [String]) -> Options {
    var o = Options()
    var i = 0
    while i < argv.count {
        switch argv[i] {
        case "-h", "--help": o.showHelp = true
        case "--fast": o.fast = true
        case "--no-correction": o.noCorrection = true
        case "--list-languages": o.listLanguages = true
        case "-l", "--languages":
            i += 1
            if i < argv.count {
                o.languages = argv[i].split(separator: ",").map {
                    $0.trimmingCharacters(in: .whitespaces)
                }
            }
        default:
            FileHandle.standardError.write("clip2md: unknown option \(argv[i])\n".data(using: .utf8)!)
        }
        i += 1
    }
    return o
}

let helpText = """
clip2md — convert the current clipboard contents to Markdown on stdout.

USAGE:
    clip2md [options]

OPTIONS:
    -l, --languages <a,b>   Comma-separated OCR language hints (e.g. en-US,fr-FR).
        --list-languages    Print the languages Vision OCR supports and exit.
        --fast              Use the fast (lower-accuracy) recognition path.
        --no-correction     Disable language-based spelling correction.
    -h, --help              Show this help.

BEHAVIOR:
    If the clipboard holds an image, its text is extracted with macOS Vision OCR.
    Otherwise clipboard text (RTF/HTML flattened to plain text, or plain text) is
    emitted unchanged. Exit code 3 means the clipboard held nothing convertible.
"""

// MARK: - stdout / stderr helpers

func emit(_ s: String) { FileHandle.standardOutput.write(s.data(using: .utf8)!) }
func warn(_ s: String) { FileHandle.standardError.write((s + "\n").data(using: .utf8)!) }

// MARK: - OCR

/// Recognize text in an image, returning lines top-to-bottom.
func ocr(_ cgImage: CGImage, _ o: Options) -> [String] {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = o.fast ? .fast : .accurate
    request.usesLanguageCorrection = !o.noCorrection
    if !o.languages.isEmpty {
        request.recognitionLanguages = o.languages
    }

    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    do {
        try handler.perform([request])
    } catch {
        warn("clip2md: OCR failed: \(error.localizedDescription)")
        return []
    }

    guard let observations = request.results else { return [] }

    // Sort top-to-bottom (Vision's y origin is bottom-left), then left-to-right
    // for observations on roughly the same line.
    let sorted = observations.sorted { a, b in
        let ay = a.boundingBox.origin.y, by = b.boundingBox.origin.y
        if abs(ay - by) > 0.01 { return ay > by }
        return a.boundingBox.origin.x < b.boundingBox.origin.x
    }

    return sorted.compactMap { $0.topCandidates(1).first?.string }
}

/// Pull a CGImage out of whatever image representation the clipboard holds.
func clipboardImage(_ pb: NSPasteboard) -> CGImage? {
    if let images = pb.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
       let nsImage = images.first {
        var rect = CGRect(origin: .zero, size: nsImage.size)
        if let cg = nsImage.cgImage(forProposedRect: &rect, context: nil, hints: nil) {
            return cg
        }
    }
    // Fallback: raw TIFF/PNG data on the pasteboard.
    for type in [NSPasteboard.PasteboardType.tiff, NSPasteboard.PasteboardType.png] {
        if let data = pb.data(forType: type),
           let src = CGImageSourceCreateWithData(data as CFData, nil),
           let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) {
            return cg
        }
    }
    return nil
}

// MARK: - Text extraction

/// Flatten RTF or HTML on the clipboard to plain text; otherwise plain string.
func clipboardText(_ pb: NSPasteboard) -> String? {
    if let rtf = pb.data(forType: .rtf),
       let attr = try? NSAttributedString(
           data: rtf,
           options: [.documentType: NSAttributedString.DocumentType.rtf],
           documentAttributes: nil) {
        return attr.string
    }
    if let html = pb.data(forType: .html),
       let attr = try? NSAttributedString(
           data: html,
           options: [.documentType: NSAttributedString.DocumentType.html,
                     .characterEncoding: String.Encoding.utf8.rawValue],
           documentAttributes: nil) {
        return attr.string
    }
    return pb.string(forType: .string)
}

// MARK: - Main

let opts = parseArgs(Array(CommandLine.arguments.dropFirst()))

if opts.showHelp {
    emit(helpText + "\n")
    exit(0)
}

if opts.listLanguages {
    let req = VNRecognizeTextRequest()
    req.recognitionLevel = opts.fast ? .fast : .accurate
    let langs = (try? req.supportedRecognitionLanguages()) ?? []
    emit(langs.joined(separator: "\n") + "\n")
    exit(0)
}

let pasteboard = NSPasteboard.general

// Prefer an image if one is present (screenshots, copied pictures).
if let cg = clipboardImage(pasteboard) {
    let lines = ocr(cg, opts)
    if lines.isEmpty {
        warn("clip2md: image found on clipboard but no text was recognized.")
        exit(3)
    }
    emit(lines.joined(separator: "\n") + "\n")
    exit(0)
}

// Otherwise emit clipboard text.
if let text = clipboardText(pasteboard), !text.isEmpty {
    emit(text.hasSuffix("\n") ? text : text + "\n")
    exit(0)
}

warn("clip2md: clipboard holds nothing convertible to Markdown.")
exit(3)
