// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ChainDomain",
    platforms: [
        .macOS(.v14),
        .iOS(.v18)
    ],
    targets: [
        .target(
            name: "ChainDomain",
            path: "Chain",
            exclude: [
                "ChainApp.swift",
                "Info.plist",
                "Assets.xcassets",
                "Views",
                "ContentView.swift",
                "Models/Habit.swift",
                "Models/HabitEntry.swift",
                "Models/Companion.swift",
                "Connectors/HealthKitConnector.swift",
                "Connectors/ConnectorService.swift",
                "Connectors/HabitVerifier.swift",
                "Connectors/NotificationScheduler.swift",
                "Connectors/SmartNotificationScheduler.swift"
            ],
            sources: ["Domain", "Connectors", "Models"]
        ),
        .testTarget(
            name: "ChainDomainTests",
            dependencies: ["ChainDomain"],
            path: "ChainTests"
        )
    ]
)
