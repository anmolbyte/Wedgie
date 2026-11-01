// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Wedgie",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Wedgie",
            path: "Sources/Wedgie"
        ),
        .executableTarget(
            name: "WedgieIcon",
            path: "Sources/WedgieIcon"
        )
    ],
    swiftLanguageModes: [.v6]
)
