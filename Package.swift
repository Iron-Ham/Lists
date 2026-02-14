// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ListKit",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "ListKit",
            targets: ["ListKit"]
        ),
        .library(
            name: "Lists",
            targets: ["Lists"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/Instagram/IGListKit", from: "5.0.0"),
        .package(url: "https://github.com/jessesquires/ReactiveCollectionsKit", from: "0.2.0"),
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.3"),
    ],
    targets: [
        .target(
            name: "ListKit",
            path: "Sources/ListKit"
        ),
        .target(
            name: "Lists",
            dependencies: ["ListKit"],
            path: "Sources/Lists"
        ),
        .testTarget(
            name: "ListKitTests",
            dependencies: ["ListKit"],
            path: "Tests/ListKitTests"
        ),
        .testTarget(
            name: "ListsTests",
            dependencies: ["Lists", "ListKit"],
            path: "Tests/ListsTests"
        ),
        .testTarget(
            name: "Benchmarks",
            dependencies: [
                "ListKit",
                "Lists",
                .product(name: "IGListDiffKit", package: "IGListKit"),
                .product(name: "ReactiveCollectionsKit", package: "ReactiveCollectionsKit"),
            ],
            path: "Tests/Benchmarks"
        ),
    ]
)
