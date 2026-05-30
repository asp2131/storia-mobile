// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "flutter_tts",
    platforms: [
        .iOS("12.0")
    ],
    products: [
        .library(name: "flutter-tts", targets: ["flutter_tts"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "flutter_tts",
            dependencies: [],
            path: "Sources/flutter_tts",
            publicHeadersPath: ".",
            resources: []
        )
    ]
)
