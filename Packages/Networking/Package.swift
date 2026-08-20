// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Networking",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "Networking",
            targets: ["Networking"]),
    ],
    dependencies: [
//        .package(path: "../CoreDependencies")
        .package(path: "../CoreModels")
    ],
    targets: [
        .target(
            name: "Networking",
            dependencies: [
//                .product(name: "CoreDependencies",
//                         package: "CoreDependencies")
                .product(name: "CoreModels",
                         package: "CoreModels")
            ],
            exclude: ["OpenAI"]
        ),
        .testTarget(
            name: "NetworkingTests",
            dependencies: ["Networking"],
            exclude: ["Clients/OpenAIClientTests.swift"]
        ),
    ]
)
