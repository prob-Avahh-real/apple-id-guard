// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AppleIDGuard",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "AppleIDGuard", targets: ["AppleIDGuard"]),
    ],
    targets: [
        .target(
            name: "AppleIDGuard",
            path: "Sources/AppleIDGuard",
            exclude: ["AppleIDGuardApp.swift"]
        ),
        .testTarget(
            name: "AppleIDGuardTests",
            dependencies: ["AppleIDGuard"],
            path: "Tests/AppleIDGuardTests"
        ),
    ]
)
