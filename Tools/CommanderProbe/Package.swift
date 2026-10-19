// swift-tools-version:5.9
import PackageDescription

// The probe uses the library from this repository, so it always runs the code under test.
let package = Package(
    name: "CommanderProbe",
    platforms: [.macOS(.v14)],
    dependencies: [.package(path: "../..")],
    targets: [
        .executableTarget(
            name: "CommanderProbe",
            dependencies: [.product(name: "S3XYCommander", package: "S3XYCommander")],
            path: "Sources/CommanderProbe"
        ),
    ]
)
