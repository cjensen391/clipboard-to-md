// Renders the app icon (an SF Symbol on a rounded gradient tile) into an
// .iconset, which build-app.sh turns into AppIcon.icns via iconutil. No image
// assets checked in — the icon is generated, so it always matches the menu-bar
// glyph. Run: swift Packaging/make-icon.swift <output-iconset-dir>
import AppKit

let args = CommandLine.arguments
guard args.count == 2 else {
    FileHandle.standardError.write(Data("usage: make-icon.swift <iconset-dir>\n".utf8))
    exit(2)
}
let outDir = URL(fileURLWithPath: args[1])
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

func render(_ px: Int) -> Data {
    let size = CGFloat(px)
    // Draw into a bitmap rep via an explicit context — NSImage.lockFocus is
    // unreliable in a headless (no-NSApp) command-line process.
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { fatalError("bitmap alloc failed at \(px)px") }

    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx
    defer { NSGraphicsContext.restoreGraphicsState() }

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    // Rounded tile with a top-to-bottom blue gradient (macOS icon idiom).
    let inset = size * 0.06
    let tile = rect.insetBy(dx: inset, dy: inset)
    let radius = tile.width * 0.225
    let path = NSBezierPath(roundedRect: tile, xRadius: radius, yRadius: radius)
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.36, green: 0.56, blue: 0.98, alpha: 1),
        NSColor(calibratedRed: 0.18, green: 0.36, blue: 0.86, alpha: 1)
    ])
    gradient?.draw(in: path, angle: -90)

    // Centered document glyph.
    let cfg = NSImage.SymbolConfiguration(pointSize: size * 0.5, weight: .medium)
        .applying(.init(paletteColors: [.white]))
    if let symbol = NSImage(systemSymbolName: "doc.richtext", accessibilityDescription: nil)?
        .withSymbolConfiguration(cfg) {
        let s = symbol.size
        let origin = NSPoint(x: (size - s.width) / 2, y: (size - s.height) / 2)
        symbol.draw(at: origin, from: .zero, operation: .sourceOver, fraction: 1)
    }

    ctx.flushGraphics()
    guard let png = rep.representation(using: .png, properties: [:]) else {
        fatalError("png encode failed at \(px)px")
    }
    return png
}

// Standard iconset members (1x and 2x for each size).
let specs: [(name: String, px: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024)
]
for spec in specs {
    let data = render(spec.px)
    let url = outDir.appendingPathComponent("\(spec.name).png")
    try data.write(to: url)
}
print("wrote \(specs.count) icons to \(outDir.path)")
