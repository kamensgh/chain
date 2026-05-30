// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ChainDomain",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    targets: [
        .target(
            name: "ChainDomain",
            path: "Chain",
            exclude: ["ChainApp.swift", "Info.plist", "Assets.xcassets"],
            sources: ["Domain", "Connectors", "Models"],
            swiftSettings: [.unsafeFlags([])]
        ),
        .testTarget(
            name: "ChainDomainTests",
            dependencies: ["ChainDomain"],
            path: "ChainTests"
        )
    ]
)
