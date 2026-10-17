// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "WorldTrailsCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "WorldTrailsCore", targets: ["WorldTrailsCore"])
    ],
    targets: [
        .target(
            name: "WorldTrailsCore",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "WorldTrailsCoreTests",
            dependencies: ["WorldTrailsCore"]
        )
    ]
)
