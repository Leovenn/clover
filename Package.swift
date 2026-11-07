// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Clover",
    platforms: [.macOS(.v26)],
    targets: [
        .target(name: "CloverCore"),
        .executableTarget(name: "cl", dependencies: ["CloverCore"]),
        .executableTarget(name: "Clover", dependencies: ["CloverCore"]),
        .testTarget(name: "CloverCoreTests", dependencies: ["CloverCore"]),
    ]
)
