// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "reactorium",
    platforms: [
        .macOS(.v11), .iOS(.v14), .tvOS(.v14)
    ],
    products: [
        .library(
            name: "Reactorium",
            targets: ["Reactorium"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-clocks", from: "0.2.0"),
        .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "0.8.0")
    ],
    targets: [
        .target(
            name: "Reactorium",
            dependencies: [
                .product(name: "Clocks", package: "swift-clocks"),
                .product(name: "CustomDump", package: "swift-custom-dump")
            ]),
        .testTarget(
            name: "ReactoriumTests",
            dependencies: ["Reactorium"]),
    ]
)

#if false
for target in package.targets where target.type == .regular {
    target.swiftSettings = [
        .unsafeFlags(["-Xfrontend", "-warn-long-function-bodies=200"],
                     .when(configuration: .debug)),
        .unsafeFlags(["-Xfrontend", "-warn-concurrency"]),
        .unsafeFlags(["-Xfrontend", "-enable-actor-data-race-checks"])
    ] + (target.swiftSettings ?? [])
}
#endif
