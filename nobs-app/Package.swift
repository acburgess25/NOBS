// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "NOBSKit",
    platforms: [
        // Apple Intelligence / FoundationModels framework requires iOS 26 / macOS 15.
        // Code that imports `FoundationModels` is guarded with `#if canImport(...)` and
        // `if #available(...)` so the package still compiles on older platforms.
        .iOS(.v26),
        .macOS(.v15),
    ],
    products: [
        // Full assistant library
        .library(name: "NOBSKit", targets: [
            "NOBSCore",
            "NOBSAssistant",
            "NOBSCallKit",
            "NOBSiMessage",
            "NOBSHomeKit",
            "NOBSCalendar",
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
        .library(name: "NOBSCalendar",  targets: ["NOBSCalendar"]),
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
            dependencies: ["NOBSCore", "NOBSSecurity"],
            path: "Sources/NOBSDatabase"
        ),
        .target(
            name: "NOBSAssistant",
            dependencies: ["NOBSCore", "NOBSDatabase", "NOBSSecurity"],
            path: "Sources/NOBSAssistant"
        ),
        .target(
            name: "NOBSCallKit",
            dependencies: ["NOBSCore", "NOBSDatabase", "NOBSSecurity"],
            path: "Sources/NOBSCallKit"
        ),
        .target(
            name: "NOBSiMessage",
            dependencies: ["NOBSCore", "NOBSDatabase", "NOBSSecurity"],
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
            name: "NOBSCalendar",
            dependencies: ["NOBSCore"],
            path: "Sources/NOBSCalendar"
        ),

        .target(
            name: "NOBSIntents",
            dependencies: ["NOBSCore", "NOBSAssistant", "NOBSDatabase", "NOBSHomeKit", "NOBSReminders", "NOBSCalendar"],
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
