// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TextPolisher",
    platforms: [
        .macOS(.v26)
    ],
    targets: [
        .executableTarget(
            name: "TextPolisher",
            path: "Sources/text_polisher"
        )
    ],
    swiftLanguageModes: [.v5]
)
