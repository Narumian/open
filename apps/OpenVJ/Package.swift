// swift-tools-version: 5.9

import Foundation
import PackageDescription

let packageDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let syphonXCFramework = packageDir.appendingPathComponent("Vendor/Syphon.xcframework/Info.plist")
let syphonAvailable = FileManager.default.fileExists(atPath: syphonXCFramework.path)
let swiftXPackage = packageDir.appendingPathComponent("../../../SwiftXUI")
let swiftXAvailable = FileManager.default.fileExists(atPath: swiftXPackage.appendingPathComponent("Package.swift").path)

let cwgpuDependency: Target.Dependency = swiftXAvailable
    ? .product(name: "CWGPU", package: "SwiftXUI")
    : .byName(name: "CWGPU")

var targets: [Target] = []
if !swiftXAvailable {
    targets.append(
        .binaryTarget(
            name: "CWGPU",
            path: "Vendor/CWGPU.xcframework"
        )
    )
}

targets.append(contentsOf: [
    .target(
        name: "OpenUI",
        path: "Sources/OpenUI",
        exclude: [
            "Deferred/README.md",
            "Deferred/VJPlaybackDSL.swift",
        ]
    ),
    .target(
        name: "OpenVJApple",
        dependencies: [cwgpuDependency],
        path: "Sources/OpenVJApple",
        publicHeadersPath: "include",
        linkerSettings: [
            .linkedFramework("Metal"),
            .linkedFramework("QuartzCore"),
        ]
    ),
    .target(
        name: "OpenVJ",
        dependencies: [cwgpuDependency, "OpenVJApple", "OpenUI"],
        path: "Sources/OpenVJ",
        linkerSettings: [
            .linkedFramework("AVFoundation"),
            .linkedFramework("Metal"),
            .linkedFramework("QuartzCore"),
            .linkedLibrary("c++"),
        ]
    ),
])

var openVJAppDependencies: [Target.Dependency] = ["OpenVJ"]
var products: [Product] = [
    .library(name: "OpenUI", targets: ["OpenUI"]),
    .library(name: "OpenVJ", targets: ["OpenVJ"]),
    .executable(name: "OpenVJApp", targets: ["OpenVJApp"]),
    .executable(name: "OpenVJRender", targets: ["OpenVJRender"]),
]

if syphonAvailable {
    targets.append(.binaryTarget(name: "Syphon", path: "Vendor/Syphon.xcframework"))
    targets.append(
        .target(
            name: "OpenVJSyphon",
            dependencies: ["OpenVJ", "Syphon", cwgpuDependency],
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
        name: "OpenVJRender",
        dependencies: ["OpenVJ", "OpenUI"],
        path: "Sources/OpenVJRender",
        linkerSettings: [
            .linkedFramework("AppKit"),
            .linkedFramework("QuartzCore"),
            .linkedFramework("Metal"),
            .linkedFramework("ImageIO"),
            .linkedFramework("UniformTypeIdentifiers"),
        ]
    )
)

var packageDependencies: [Package.Dependency] = []
if swiftXAvailable {
    packageDependencies.append(.package(path: swiftXPackage.path))
}

if swiftXAvailable {
    targets.append(
        .target(
            name: "OpenVJXRender",
            dependencies: [
                "OpenUI",
                "OpenVJ",
                cwgpuDependency,
                .product(name: "XRender", package: "SwiftXUI"),
                .product(name: "XRenderWGPU", package: "SwiftXUI"),
                .product(name: "XRenderApple", package: "SwiftXUI"),
                .product(name: "XShader", package: "SwiftXUI"),
                .product(name: "XUI", package: "SwiftXUI"),
                .product(name: "XUIHost", package: "SwiftXUI"),
            ],
            path: "Sources/OpenVJXRender",
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreVideo"),
                .linkedFramework("Metal"),
                .linkedFramework("QuartzCore"),
                .linkedLibrary("c++"),
            ]
        )
    )
    products.append(.library(name: "OpenVJXRender", targets: ["OpenVJXRender"]))
    openVJAppDependencies.append("OpenVJXRender")
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
    dependencies: packageDependencies,
    targets: targets
)
