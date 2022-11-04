// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "reactorium",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(
            name: "Reactorium",
            targets: ["Reactorium"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Reactorium",
            dependencies: []),
        .testTarget(
            name: "ReactoriumTests",
            dependencies: ["Reactorium"]),
    ]
)

for target in package.targets where target.type == .regular {
    target.swiftSettings = [
        .unsafeFlags(["-Xfrontend", "-warn-long-function-bodies=200"],
                     .when(configuration: .debug)),
        .unsafeFlags(["-Xfrontend", "-warn-concurrency"]),
        .unsafeFlags(["-Xfrontend", "-enable-actor-data-race-checks"])
    ] + (target.swiftSettings ?? [])
}
