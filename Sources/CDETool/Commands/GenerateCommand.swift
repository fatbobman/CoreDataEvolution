//
//  ------------------------------------------------
//  Original project: CoreDataEvolution
//  Created on 2026/3/5 by Fatbobman(东坡肘子)
//  X: @fatbobman
//  Mastodon: @fatbobman@mastodon.social
//  GitHub: @fatbobman
//  Blog: https://fatbobman.com
//  ------------------------------------------------
//  Copyright © 2024-present Fatbobman. All rights reserved.

import ArgumentParser
import CoreDataEvolutionToolingCore

struct GenerateCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "generate",
    abstract: "Generate Swift model code from Core Data models."
  )

  @Option(name: .long, help: "Path to model (.xcdatamodeld/.xcdatamodel/.momd).")
  var modelPath: String

  @Option(name: .long, help: "Specific model version name. Defaults to current/latest.")
  var modelVersion: String?

  @Option(name: .long, help: "Path to momc binary.")
  var momcBin: String?

  @Option(name: .long, help: "Output directory for generated files.")
  var outputDir: String

  @Option(name: .long, help: "Swift module name for generated code.")
  var moduleName: String

  @Option(name: .long, help: "Access level: internal/public.")
  var accessLevel: ToolingAccessLevel = .internal

  @Flag(name: .long, help: "Generate a single output file.")
  var singleFile = false

  @Flag(name: .long, inversion: .prefixedNo, help: "Split outputs by entity.")
  var splitByEntity = true

  @Option(name: .long, help: "Overwrite mode: none/changed/all.")
  var overwrite: ToolingOverwriteMode = .none

  @Flag(name: .long, help: "Clean stale generated files in output directory.")
  var cleanStale = false

  @Flag(name: .long, help: "Preview changes without writing files.")
  var dryRun = false

  @Option(name: .long, help: "Format mode: none/swift-format/swiftformat.")
  var format: ToolingFormatMode = .none

  @Option(name: .long, help: "Header template path.")
  var headerTemplate: String?

  @Flag(name: .long, help: "Generate convenience init.")
  var generateInit = false

  @Option(name: .long, help: "Relationship setter policy: none/warning/plain.")
  var relationshipSetterPolicy: ToolingRelationshipGenerationPolicy = .warning

  @Option(name: .long, help: "Relationship count policy: none/warning/plain.")
  var relationshipCountPolicy: ToolingRelationshipGenerationPolicy = .none

  @Option(name: .long, help: "Decode failure policy: fallbackToDefaultValue/debugAssertNil.")
  var defaultDecodeFailurePolicy: ToolingDecodeFailurePolicy = .fallbackToDefaultValue

  @Option(name: .long, help: "Path to JSON config file.")
  var config: String?

  mutating func run() throws {
    try failUser(
      code: .notImplemented,
      message: "generate is not implemented yet."
    )
  }
}
