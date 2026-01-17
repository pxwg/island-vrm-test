// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "island",
    platforms: [
        .macOS(.v14),
    ],
    targets: [
        .executableTarget(
            name: "island",
            path: "Sources",
            exclude: [
                "Package.swift",
                "WebResources",
            ],
            resources: [
                .copy("WebResources"),
            ]
        ),
    ]
)
