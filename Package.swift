// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Kairo",
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
                "Extensions/ShareExtension/ShareExtensionNotes.md",
                "Extensions/ShareExtension/ShareViewController.swift",
                "Resources"
            ],
            resources: []
        ),
        .testTarget(
            name: "KairoCoreTests",
            dependencies: ["KairoCore"],
            path: "Tests"
        )
    ]
)
