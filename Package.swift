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
    .visionOS(.v1),
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
    .executable(
      name: "cde-tool",
      targets: ["CDETool"],
    ),
    .library(
      name: "CoreDataEvolutionToolingCore",
      targets: ["CoreDataEvolutionToolingCore"],
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/swiftlang/swift-syntax", "600.0.0"..<"603.0.0"),
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
  ],
  targets: [
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    .macro(
      name: "CoreDataEvolutionMacros",
      dependencies: [
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
        .product(name: "SwiftDiagnostics", package: "swift-syntax"),
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
    .target(
      name: "CoreDataEvolutionToolingCore",
      dependencies: [
        .product(name: "SwiftParser", package: "swift-syntax"),
        .product(name: "SwiftSyntax", package: "swift-syntax"),
      ]
    ),
    .testTarget(
      name: "CoreDataEvolutionToolingCoreTests",
      dependencies: [
        "CoreDataEvolutionToolingCore"
      ]
    ),
    .testTarget(
      name: "CDEToolTests",
      dependencies: [
        "CDETool",
        "CoreDataEvolutionToolingCore",
      ]
    ),
    .testTarget(
      name: "CoreDataEvolutionTests",
      dependencies: [
        "CoreDataEvolution"
      ],
      exclude: [
        "CoreDataEvolution-Package.xctestplan"
      ]
    ),
    .testTarget(
      name: "CoreDataEvolutionMacroTests",
      dependencies: [
        "CoreDataEvolutionMacros",
        .product(name: "SwiftParser", package: "swift-syntax"),
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacroExpansion", package: "swift-syntax"),
        .product(name: "SwiftBasicFormat", package: "swift-syntax"),
      ],
      exclude: [
        "Fixtures",
        "__Snapshots__",
      ]
    ),
    .executableTarget(name: "CoreDataEvolutionClient", dependencies: ["CoreDataEvolution"]),
    .executableTarget(
      name: "CDETool",
      dependencies: [
        "CoreDataEvolutionToolingCore",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ]
    ),
  ],
  swiftLanguageModes: [.v6],
)
