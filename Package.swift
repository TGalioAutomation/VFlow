// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "VFlow",
    defaultLocalization: "vi",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "VFlow", targets: ["VFlowApp"]),
        .library(name: "VFlowCore", targets: ["VFlowCore"]),
        .library(name: "VFlowPlatform", targets: ["VFlowPlatform"]),
        .library(name: "VFlowUI", targets: ["VFlowUI"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "VFlowCore",
            dependencies: [],
            path: "Sources/VFlowCore"
        ),
        .target(
            name: "VFlowPlatform",
            dependencies: ["VFlowCore"],
            path: "Sources/VFlowPlatform"
        ),
        .target(
            name: "VFlowUI",
            dependencies: ["VFlowCore", "VFlowPlatform"],
            path: "Sources/VFlowUI"
        ),
        .executableTarget(
            name: "VFlowApp",
            dependencies: ["VFlowCore", "VFlowPlatform", "VFlowUI"],
            path: "Sources/VFlowApp"
        ),
        .testTarget(
            name: "VFlowTests",
            dependencies: ["VFlowCore", "VFlowPlatform", "VFlowUI"],
            path: "Tests/VFlowTests"
        )
    ]
)
