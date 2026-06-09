// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MobileAutomationSupport",
    platforms: [
        .macOS(.v26),
        .iOS(.v26)
    ],
    products: [
        .library(
            name: "ActionSupport",
            targets: [
                "ActionSupport",
            ]
        ),
        .library(
            name: "MobileAutomationSupport",
            targets: [
                "MobileAutomationSupport",
            ]
        ),
        .executable(
            name: "mobile-automation",
            targets: [
                "CLI",
            ]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.7.1"),
    ],
    targets: [
        .target(
            name: "ActionSupport"
        ),
        .target(
            name: "MobileAutomationSupport",
            dependencies: [
                .target(name: "ActionSupport"),
            ]
        ),
        .executableTarget(
            name: "CLI",
            dependencies: [
                .target(name: "MobileAutomationSupport"),
                .target(name: "ActionSupport"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
    ]
)
