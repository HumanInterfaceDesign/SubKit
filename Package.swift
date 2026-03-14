// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SubKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v12),
        .tvOS(.v15),
        .watchOS(.v8),
        .visionOS(.v1),
    ],
    products: [
        .library(
            name: "SubKit",
            targets: ["SubKit"]
        ),
        .library(
            name: "SubKitUI",
            targets: ["SubKitUI"]
        ),
    ],
    targets: [
        .target(
            name: "SubKit"
        ),
        .target(
            name: "SubKitUI",
            dependencies: ["SubKit"]
        ),
        .testTarget(
            name: "SubKitTests",
            dependencies: ["SubKit"],
            resources: [
                .copy("Fixtures/SubKitTest.storekit")
            ]
        ),
        .testTarget(
            name: "SubKitUITests",
            dependencies: ["SubKitUI"]
        ),
    ]
)
