// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NextUp",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "NextUpCore"),
        .executableTarget(name: "NextUp", dependencies: ["NextUpCore"]),
        .testTarget(name: "NextUpTests", dependencies: ["NextUpCore"]),
    ]
)
