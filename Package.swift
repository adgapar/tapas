// swift-tools-version: 6.2
import PackageDescription
import Foundation

// Command Line Tools 6.4 drops TestingMacros unless the plugin is loaded by hand.
let testingMacros = "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib"
let testSettings: [SwiftSetting] = FileManager.default.isReadableFile(atPath: testingMacros)
    ? [.unsafeFlags(["-load-plugin-library", testingMacros])]
    : []

let package = Package(
    name: "Tapas",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "TapasCore", targets: ["TapasCore"]),
    ],
    targets: [
        .target(name: "TapasCore"),
        .testTarget(
            name: "TapasCoreTests",
            dependencies: ["TapasCore"],
            swiftSettings: testSettings
        ),
    ]
)
