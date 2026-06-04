// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Kairo",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "KairoCore", targets: ["KairoCore"])
    ],
    targets: [
        .target(
            name: "KairoCore",
            path: "Kairo",
            exclude: [
                "App/KairoApp.swift",
                "App/LlamaCppLocalModelRuntime.swift",
                "Extensions/ShareExtension/ShareExtensionNotes.md",
                "Extensions/ShareExtension/ShareViewController.swift"
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "KairoCoreTests",
            dependencies: ["KairoCore"],
            path: "Tests"
        )
    ]
)
