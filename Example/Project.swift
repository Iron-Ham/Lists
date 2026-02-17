// ABOUTME: Tuist project manifest for the ListKitExample demo app.
// ABOUTME: Declares a single iOS app target depending on ListKit and Lists.
import ProjectDescription

let project = Project(
  name: "ListKitExample",
  settings: .settings(
    base: [
      "SWIFT_VERSION": "6",
      "SWIFT_TREAT_WARNINGS_AS_ERRORS": "YES",
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
        "UILaunchScreen": [:]
      ]),
      sources: ["Sources/**"],
      dependencies: [
        .project(target: "ListKit", path: ".."),
        .project(target: "Lists", path: ".."),
      ]
    )
  ]
)
