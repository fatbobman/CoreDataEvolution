// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import Foundation
import PackageDescription

let package = Package(
  name: "CoreDataEvolution",
  platforms: [
    .iOS(.v13),
    .macOS(.v10_15),
    .tvOS(.v13),
    .watchOS(.v6),
  ],
  products: [
    // Products define the executables and libraries a package produces, making them visible to other packages.
    .library(
      name: "CoreDataEvolution",
      targets: ["CoreDataEvolution"],
    ),
    .executable(
      name: "CoreDataEvolutionClient",
      targets: ["CoreDataEvolutionClient"],
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/swiftlang/swift-syntax", "600.0.0"..<"603.0.0")
  ],
  targets: [
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    .macro(
      name: "CoreDataEvolutionMacros",
      dependencies: [
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
      ],
    ),
    .target(
      name: "CoreDataEvolution",
      dependencies: [
        "CoreDataEvolutionMacros"
      ],
      swiftSettings: [
        .enableUpcomingFeature("InternalImportsByDefault")
      ],
    ),
    .testTarget(
      name: "CoreDataEvolutionTests",
      dependencies: [
        "CoreDataEvolution"
      ],
    ),
    .executableTarget(name: "CoreDataEvolutionClient", dependencies: ["CoreDataEvolution"]),
  ],
  swiftLanguageModes: [.v6],
)
