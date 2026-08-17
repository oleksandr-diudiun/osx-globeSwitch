// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "GlobeSwitch",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "GlobeSwitch", targets: ["GlobeSwitch"])
    ],
    targets: [
        .target(
            name: "GlobeSwitchCore",
            path: "Sources/GlobeSwitchCore"
        ),
        .executableTarget(
            name: "GlobeSwitch",
            dependencies: ["GlobeSwitchCore"],
            path: "Sources/GlobeSwitch"
        ),
        .testTarget(
            name: "GlobeSwitchCoreTests",
            dependencies: ["GlobeSwitchCore"],
            path: "Tests/GlobeSwitchCoreTests"
        )
    ]
)
