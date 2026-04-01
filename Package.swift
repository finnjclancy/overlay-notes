// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "OverlayNotes",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "OverlayNotes",
            targets: ["OverlayNotes"]
        )
    ],
    targets: [
        .executableTarget(
            name: "OverlayNotes"
        )
    ]
)
