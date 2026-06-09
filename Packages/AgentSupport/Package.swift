// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AgentSupport",
    platforms: [
        .macOS(.v26),
        .iOS(.v26)
    ],
    products: [
        .library(
            name: "AgentSupport",
            targets: [
                "AgentSupport",
            ]
        ),
        .library(
            name: "AppSupport",
            targets: [
                "AppSupport",
            ]
        ),
    ],
    targets: [
        .target(
            name: "AgentSupport"
        ),
        .target(
            name: "AppSupport"
        ),
    ]
)
