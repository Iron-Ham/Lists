import ProjectDescription

let project = Project(
  name: "ListKit",
  settings: .settings(
    base: [
      "SWIFT_VERSION": "6",
      "SWIFT_TREAT_WARNINGS_AS_ERRORS": "YES",
    ],
    defaultSettings: .recommended
  ),
  targets: [
    .target(
      name: "ListKit",
      destinations: .iOS,
      product: .framework,
      bundleId: "com.listkit.ListKit",
      deploymentTargets: .iOS("17.0"),
      sources: ["Sources/ListKit/**"],
      dependencies: []
    ),
    .target(
      name: "Lists",
      destinations: .iOS,
      product: .framework,
      bundleId: "com.listkit.Lists",
      deploymentTargets: .iOS("17.0"),
      sources: ["Sources/Lists/**"],
      dependencies: [
        .target(name: "ListKit")
      ]
    ),
    .target(
      name: "ListKitTests",
      destinations: .iOS,
      product: .unitTests,
      bundleId: "com.listkit.ListKitTests",
      deploymentTargets: .iOS("17.0"),
      sources: ["Tests/ListKitTests/**"],
      dependencies: [
        .target(name: "ListKit")
      ]
    ),
    .target(
      name: "ListsTests",
      destinations: .iOS,
      product: .unitTests,
      bundleId: "com.listkit.ListsTests",
      deploymentTargets: .iOS("17.0"),
      sources: ["Tests/ListsTests/**"],
      dependencies: [
        .target(name: "Lists"),
        .target(name: "ListKit"),
      ]
    ),
    .target(
      name: "Benchmarks",
      destinations: .iOS,
      product: .unitTests,
      bundleId: "com.listkit.Benchmarks",
      deploymentTargets: .iOS("17.0"),
      sources: ["Tests/Benchmarks/**"],
      dependencies: [
        .target(name: "ListKit"),
        .target(name: "Lists"),
        .external(name: "IGListDiffKit"),
        .external(name: "ReactiveCollectionsKit"),
      ],
      settings: .settings(base: [
        "OTHER_LDFLAGS": ["-lc++", "-ObjC"]
      ])
    ),
  ]
)
