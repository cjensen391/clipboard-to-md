// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "clip2md",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(name: "clip2md", path: "Sources/clip2md")
    ]
)
