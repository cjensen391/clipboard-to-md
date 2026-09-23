// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ClipboardToMarkdown",
    platforms: [
        .macOS("14.0")
    ],
    dependencies: [
        .package(
            url: "https://github.com/sindresorhus/KeyboardShortcuts",
            from: "2.0.0"
        )
    ],
    targets: [
        .executableTarget(
            name: "ClipboardToMarkdown",
            dependencies: [
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts")
            ],
            path: "Sources/ClipboardToMarkdown"
        ),
        .testTarget(
            name: "ClipboardToMarkdownTests",
            dependencies: ["ClipboardToMarkdown"],
            path: "Tests/ClipboardToMarkdownTests"
        )
    ]
)
