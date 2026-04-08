// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "Dog",
    platforms: [
        .iOS(.v14),
        .macOS(.v11),
        .watchOS(.v7),
        .tvOS(.v14),
    ],
    products: [
        .library(name: "Dog", targets: ["Dog"]),
    ],
    targets: [
        .target(name: "Dog", dependencies: []),
        .testTarget(name: "DogTests", dependencies: ["Dog"]),
    ]
)
