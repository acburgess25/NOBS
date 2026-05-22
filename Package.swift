// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NOBSKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        // Full assistant library
        .library(name: "NOBSKit", targets: [
            "NOBSCore",
            "NOBSAssistant",
            "NOBSCallKit",
            "NOBSiMessage",
            "NOBSHomeKit",
            "NOBSDatabase",
            "NOBSReminders",
            "NOBSSecurity",
            "NOBSIntents",
        ]),
        // Individual modules can be consumed independently
        .library(name: "NOBSCore",      targets: ["NOBSCore"]),
        .library(name: "NOBSAssistant", targets: ["NOBSAssistant"]),
        .library(name: "NOBSCallKit",   targets: ["NOBSCallKit"]),
        .library(name: "NOBSiMessage",  targets: ["NOBSiMessage"]),
        .library(name: "NOBSHomeKit",   targets: ["NOBSHomeKit"]),
        .library(name: "NOBSDatabase",  targets: ["NOBSDatabase"]),
        .library(name: "NOBSReminders", targets: ["NOBSReminders"]),
        .library(name: "NOBSSecurity",  targets: ["NOBSSecurity"]),
        .library(name: "NOBSIntents",   targets: ["NOBSIntents"]),
    ],
    targets: [
        // MARK: - Library targets
        .target(
            name: "NOBSSecurity",
            path: "Sources/NOBSSecurity"
        ),
        .target(
            name: "NOBSCore",
            path: "Sources/NOBSCore"
        ),
        .target(
            name: "NOBSDatabase",
            dependencies: ["NOBSCore"],
            path: "Sources/NOBSDatabase"
        ),
        .target(
            name: "NOBSAssistant",
            dependencies: ["NOBSCore", "NOBSDatabase"],
            path: "Sources/NOBSAssistant"
        ),
        .target(
            name: "NOBSCallKit",
            dependencies: ["NOBSCore", "NOBSDatabase"],
            path: "Sources/NOBSCallKit"
        ),
        .target(
            name: "NOBSiMessage",
            dependencies: ["NOBSCore", "NOBSDatabase"],
            path: "Sources/NOBSiMessage"
        ),
        .target(
            name: "NOBSHomeKit",
            dependencies: ["NOBSCore"],
            path: "Sources/NOBSHomeKit"
        ),
        .target(
            name: "NOBSReminders",
            dependencies: ["NOBSCore"],
            path: "Sources/NOBSReminders"
        ),


        .target(
            name: "NOBSIntents",
            dependencies: ["NOBSCore", "NOBSAssistant", "NOBSDatabase", "NOBSHomeKit", "NOBSReminders"],
            path: "Sources/NOBSIntents"
        ),

        // MARK: - Test targets
        .testTarget(
            name: "NOBSSecurityTests",
            dependencies: ["NOBSSecurity"],
            path: "Tests/NOBSSecurityTests"
        ),
        .testTarget(
            name: "NOBSCoreTests",
            dependencies: ["NOBSCore"],
            path: "Tests/NOBSCoreTests"
        ),
        .testTarget(
            name: "NOBSAssistantTests",
            dependencies: ["NOBSAssistant", "NOBSCore", "NOBSDatabase"],
            path: "Tests/NOBSAssistantTests"
        ),
        .testTarget(
            name: "NOBSDatabaseTests",
            dependencies: ["NOBSDatabase"],
            path: "Tests/NOBSDatabaseTests"
        ),
        .testTarget(
            name: "NOBSCallKitTests",
            dependencies: ["NOBSCallKit", "NOBSCore"],
            path: "Tests/NOBSCallKitTests"
        ),

        .testTarget(
            name: "NOBSRemindersTests",
            dependencies: ["NOBSReminders"],
            path: "Tests/NOBSRemindersTests"
        ),
        .testTarget(
            name: "NOBSiMessageTests",
            dependencies: ["NOBSiMessage", "NOBSCore", "NOBSDatabase"],
            path: "Tests/NOBSiMessageTests"
        ),
    ]
)
