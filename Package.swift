// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "boAtLocalizationKit",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "boAtLocalizationKit",
            targets: ["boAtLocalizationKit"]
        )
    ],
    targets: [
        .target(
            name: "boAtLocalizationKit",
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "boAtLocalizationKitTests",
            dependencies: ["boAtLocalizationKit"]
        )
    ]
)
