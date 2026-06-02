// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "DeepOCRClip",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "DeepOCRClip", targets: ["DeepOCRClip"])
    ],
    targets: [
        .executableTarget(
            name: "DeepOCRClip",
            path: "Sources/DeepOCRClip"
        )
    ]
)
