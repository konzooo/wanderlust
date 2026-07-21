// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CoreArchitecture",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "CoreArchitecture",
            targets: ["CoreArchitecture"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/firebase/firebase-ios-sdk.git",
            .upToNextMajor(from: "10.4.0")
        ),
    ],
    targets: [
        .target(
            name: "CoreArchitecture",
            dependencies: [
                .product(name: "FirebaseAnalytics", package: "firebase-ios-sdk"),
            ]
        ),
        .testTarget(
            name: "CoreArchitectureTests",
            dependencies: ["CoreArchitecture"]
        ),
    ]
)
