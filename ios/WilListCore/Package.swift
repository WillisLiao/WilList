// swift-tools-version: 6.2
// WilList's planner, parser and data, with no UI: the iOS app builds on it, and its tests
// run on a Mac with `swift test`.
import PackageDescription

let package = Package(
    name: "WilListCore",
    platforms: [.iOS(.v26), .macOS(.v15)],
    products: [.library(name: "WilListCore", targets: ["WilListCore"])],
    targets: [
        .target(name: "WilListCore"),
        .testTarget(name: "WilListCoreTests", dependencies: ["WilListCore"]),
    ]
)
