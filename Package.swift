// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Grove",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "grove", targets: ["Grove"])
    ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.11.0")
    ],
    targets: [
        .executableTarget(
            name: "Grove",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk")
            ],
            path: "Grove",
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Grove/Info.plist"
                ], .when(platforms: [.macOS]))
            ]
        ),
        .testTarget(
            name: "GroveTests",
            dependencies: ["Grove"],
            path: "GroveTests"
        )
    ]
)
