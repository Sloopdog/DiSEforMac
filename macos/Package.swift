// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DiSEMac",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "DiSEMac", targets: ["DiSEMac"]),
    ],
    targets: [
        .executableTarget(
            name: "DiSEMac",
            path: "Sources/DiSEMac"
        ),
    ]
)

