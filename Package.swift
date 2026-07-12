// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Wicit",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Wicit",
            path: "Sources/Wicit",
            swiftSettings: [
                // AppKit-heavy UI code — Swift 5 language mode keeps concurrency
                // friction low while we iterate. We can tighten to v6 later.
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
