// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "S3XYCommander",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .macCatalyst(.v16),
        .tvOS(.v16),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "S3XYCommander", targets: ["S3XYCommander"]),
    ],
    targets: [
        .target(
            name: "S3XYCommander",
            dependencies: [],
            path: "Sources/S3XYCommander"
        ),
        .testTarget(
            name: "S3XYCommanderTests",
            dependencies: ["S3XYCommander"],
            path: "Tests/S3XYCommanderTests"
        ),
    ]
)
