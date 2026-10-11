// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PhotoSweep",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "PhotoSweepLogic", targets: ["PhotoSweepLogic"])
    ],
    targets: [
        .target(
            name: "PhotoSweepLogic",
            path: "PhotoSweep",
            exclude: [
                "Assets.xcassets",
                "Info.plist",
                "PhotoSweepApp.swift",
                "Persistence",
                "Services/DeletionService.swift",
                "Services/HapticsService.swift",
                "Services/PhotoLibraryService.swift",
                "Utilities",
                "ViewModels",
                "Views"
            ],
            sources: [
                "Models/Models.swift",
                "Services/CoreServices.swift"
            ]
        ),
        .testTarget(
            name: "PhotoSweepTests",
            dependencies: ["PhotoSweepLogic"],
            path: "PhotoSweepTests",
            swiftSettings: [
                .unsafeFlags([
                    "-F/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    "-I/Library/Developer/CommandLineTools/Library/Developer/Frameworks/_Testing_Foundation.framework/Modules"
                ])
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-F/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    "-Xlinker",
                    "-rpath",
                    "-Xlinker",
                    "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    "-framework",
                    "Testing",
                    "-framework",
                    "_Testing_Foundation"
                ])
            ]
        )
    ]
)
