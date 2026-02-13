import ProjectDescription

let project = Project(
    name: "ListKitExample",
    settings: .settings(
        base: [
            "SWIFT_VERSION": "6",
        ],
        defaultSettings: .recommended
    ),
    targets: [
        .target(
            name: "ListKitExample",
            destinations: .iOS,
            product: .app,
            bundleId: "com.listkit.Example",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .extendingDefault(with: [
                "UILaunchScreen": [:],
            ]),
            sources: ["Sources/**"],
            dependencies: [
                .project(target: "ListKit", path: ".."),
                .project(target: "Lists", path: ".."),
            ]
        ),
    ]
)
