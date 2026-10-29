// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Bloquinho",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Bloquinho", path: "Sources/Bloquinho")
    ]
)
