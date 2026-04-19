// swift-tools-version:6.0

import PackageDescription

let package = Package(
    name: "icon-composer-mcp",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", exact: "0.9.0"),
    ],
    targets: [
        .executableTarget(
            name: "icon-composer-mcp",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk"),
            ]
        ),
    ]
)
