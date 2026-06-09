// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "NOBSMac",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "NOBSMac", targets: ["NOBSMac"])
    ],
    targets: [
        .executableTarget(
            name: "NOBSMac",
            path: "Sources/NOBSMac"
        )
    ]
)
