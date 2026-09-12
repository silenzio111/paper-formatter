// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WordFormatter",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "WordFormatter", targets: ["WordFormatterApp"])
    ],
    targets: [
        .executableTarget(
            name: "WordFormatterApp",
            path: "Sources/WordFormatterApp",
            resources: [
                .process("Resources")
            ]
        )
    ],
    swiftLanguageModes: [.v5]
)
