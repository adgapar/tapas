// swift-tools-version: 6.2
import PackageDescription
import Foundation

let testingMacros = "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib"
let testSettings: [SwiftSetting] = FileManager.default.isReadableFile(atPath: testingMacros)
    ? [.unsafeFlags(["-load-plugin-library", testingMacros])]
    : []

let package = Package(
    name: "TapasApp",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "Tapas", targets: ["TapasApp"]),
    ],
    dependencies: [
        .package(path: "../.."),
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0"),
        .package(url: "https://github.com/Desert-Ant-Labs/desert-ant-core.git", from: "3.1.0"),
    ],
    targets: [
        .executableTarget(
            name: "TapasApp",
            dependencies: [
                .product(name: "TapasCore", package: "Tapas"),
                .product(name: "Sparkle", package: "Sparkle"),
                .product(name: "Voz", package: "desert-ant-core"),
                .product(name: "Ear", package: "desert-ant-core"),
                .product(name: "Uhm", package: "desert-ant-core"),
                .product(name: "Redact", package: "desert-ant-core"),
            ],
            exclude: ["Info.plist"],
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
        .testTarget(name: "TapasAppTests", dependencies: ["TapasApp"], swiftSettings: testSettings),
    ]
)
