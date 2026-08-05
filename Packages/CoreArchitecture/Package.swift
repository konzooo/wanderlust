// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CoreArchitecture",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "CoreArchitecture",
            targets: ["CoreArchitecture"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/amplitude/Amplitude-Swift.git",
            .upToNextMajor(from: "1.18.6")
        ),
    ],
    targets: [
        .target(
            name: "CoreArchitecture",
            dependencies: [
                .product(name: "AmplitudeSwift", package: "Amplitude-Swift"),
            ]
        ),
        .testTarget(
            name: "CoreArchitectureTests",
            dependencies: ["CoreArchitecture"]
        ),
    ]
)
