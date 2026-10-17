// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "OpenVJ",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "OpenVJ", targets: ["OpenVJ"]),
        .executable(name: "OpenVJApp", targets: ["OpenVJApp"]),
    ],
    targets: [
        .binaryTarget(
            name: "CWGPU",
            path: "Vendor/CWGPU.xcframework"
        ),
        .target(
            name: "OpenVJApple",
            dependencies: ["CWGPU"],
            path: "Sources/OpenVJApple",
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedFramework("Metal"),
                .linkedFramework("QuartzCore"),
            ]
        ),
        .target(
            name: "OpenVJ",
            dependencies: ["CWGPU", "OpenVJApple"],
            path: "Sources/OpenVJ",
            linkerSettings: [
                .linkedFramework("Metal"),
                .linkedFramework("QuartzCore"),
                .linkedLibrary("c++"),
            ]
        ),
        .executableTarget(
            name: "OpenVJApp",
            dependencies: ["OpenVJ"],
            path: "Sources/OpenVJApp",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("QuartzCore"),
                .linkedFramework("Metal"),
            ]
        ),
    ]
)
