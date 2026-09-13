// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TapasApp",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "Tapas", targets: ["TapasApp"]),
    ],
    dependencies: [
        .package(path: "../.."),
        .package(url: "https://github.com/Desert-Ant-Labs/desert-ant-core.git", from: "3.1.0"),
    ],
    targets: [
        .executableTarget(
            name: "TapasApp",
            dependencies: [
                .product(name: "TapasCore", package: "Tapas"),
                .product(name: "Voz", package: "desert-ant-core"),
                .product(name: "Ear", package: "desert-ant-core"),
                .product(name: "Uhm", package: "desert-ant-core"),
                .product(name: "Redact", package: "desert-ant-core"),
            ],
            exclude: ["Info.plist"]
        ),
    ]
)
