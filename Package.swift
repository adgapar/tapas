// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Tapas",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "TapasCore", targets: ["TapasCore"]),
    ],
    targets: [
        .target(name: "TapasCore"),
        .testTarget(name: "TapasCoreTests", dependencies: ["TapasCore"]),
    ]
)
