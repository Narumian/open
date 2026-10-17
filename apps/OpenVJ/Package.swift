// swift-tools-version: 5.9

import Foundation
import PackageDescription

let packageDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let syphonXCFramework = packageDir.appendingPathComponent("Vendor/Syphon.xcframework/Info.plist")
let syphonAvailable = FileManager.default.fileExists(atPath: syphonXCFramework.path)

var targets: [Target] = [
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
]

var openVJAppDependencies: [Target.Dependency] = ["OpenVJ"]
var products: [Product] = [
    .library(name: "OpenVJ", targets: ["OpenVJ"]),
    .executable(name: "OpenVJApp", targets: ["OpenVJApp"]),
]

if syphonAvailable {
    targets.append(.binaryTarget(name: "Syphon", path: "Vendor/Syphon.xcframework"))
    targets.append(
        .target(
            name: "OpenVJSyphon",
            dependencies: ["OpenVJ", "Syphon", "CWGPU"],
            path: "Sources/OpenVJSyphon",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Metal"),
                .linkedFramework("IOSurface"),
            ]
        )
    )
    products.append(.library(name: "OpenVJSyphon", targets: ["OpenVJSyphon"]))
    openVJAppDependencies.append("OpenVJSyphon")
}

targets.append(
    .executableTarget(
        name: "OpenVJApp",
        dependencies: openVJAppDependencies,
        path: "Sources/OpenVJApp",
        linkerSettings: [
            .linkedFramework("AppKit"),
            .linkedFramework("QuartzCore"),
            .linkedFramework("Metal"),
        ]
    )
)

let package = Package(
    name: "OpenVJ",
    platforms: [.macOS(.v13)],
    products: products,
    targets: targets
)
