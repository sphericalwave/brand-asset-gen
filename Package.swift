// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "brand-asset-gen",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "BrandGenCore", targets: ["BrandGenCore"]),
        .executable(name: "brand-gen", targets: ["brand-gen"]),
    ],
    targets: [
        .target(name: "BrandGenCore", path: "Sources/BrandGenCore"),
        .executableTarget(name: "brand-gen", dependencies: ["BrandGenCore"], path: "Sources/brand-gen"),
    ]
)
