// swift-tools-version: 6.0

import PackageDescription

// Keep this consumer below Observation's macOS 14 baseline to catch unguarded macro references.
let package = Package(
  name: "ModelActorAvailabilityFixture",
  platforms: [.macOS(.v10_15)],
  dependencies: [.package(name: "CoreDataEvolution", path: "../..")],
  targets: [
    .executableTarget(
      name: "ModelActorAvailabilityApp",
      dependencies: [.product(name: "CoreDataEvolution", package: "CoreDataEvolution")]
    )
  ]
)
