// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "AreUWorkingTmrCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SaferNightCore", targets: ["SaferNightCore"])
    ],
    targets: [
        .target(
            name: "SaferNightCore",
            path: "Shared",
            exclude: [
                "Models/SwiftDataModels.swift",
                "Services/AppStore.swift",
                "Services/PersistenceController.swift"
            ],
            sources: [
                "Models/DomainModels.swift",
                "Services/DrinkParser.swift",
                "Services/EstimationService.swift",
                "Services/ReminderService.swift",
                "Utilities/BuzzStatus.swift",
                "Utilities/DisplayFormatter.swift"
            ]
        ),
        .testTarget(
            name: "SaferNightCoreTests",
            dependencies: ["SaferNightCore"],
            path: "Tests"
        )
    ]
)
