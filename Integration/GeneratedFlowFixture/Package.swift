// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "GeneratedFlowFixture",
  platforms: [
    .macOS(.v13)
  ],
  dependencies: [
    .package(path: "../..")
  ],
  targets: [
    .target(
      name: "GeneratedModels",
      dependencies: [
        .product(name: "CoreDataEvolution", package: "CoreDataEvolution")
      ]
    ),
    .executableTarget(
      name: "GeneratedFlowApp",
      dependencies: [
        "GeneratedModels",
        .product(name: "CoreDataEvolution", package: "CoreDataEvolution"),
      ]
    ),
  ]
)
