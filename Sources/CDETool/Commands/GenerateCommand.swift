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

  @Option(name: .long, help: "Path to source model (.xcdatamodeld/.xcdatamodel).")
  var modelPath: String?

  @Option(name: .long, help: "Specific model version name. Defaults to current/latest.")
  var modelVersion: String?

  @Option(name: .long, help: "Path to momc binary.")
  var momcBin: String?

  @Option(name: .long, help: "Output directory for generated files.")
  var outputDir: String?

  @Option(name: .long, help: "Swift module name for generated code.")
  var moduleName: String?

  @Option(name: .long, help: "Access level: internal/public.")
  var accessLevel: ToolingAccessLevel?

  @Option(name: .long, help: "Whether to generate a single output file (true/false).")
  var singleFile: Bool?

  @Option(name: .long, help: "Whether to split outputs by entity (true/false).")
  var splitByEntity: Bool?

  @Option(name: .long, help: "Overwrite mode: none/changed/all.")
  var overwrite: ToolingOverwriteMode?

  @Option(
    name: .long, help: "Whether to clean stale generated files in output directory (true/false).")
  var cleanStale: Bool?

  @Option(name: .long, help: "Whether to preview changes without writing files (true/false).")
  var dryRun: Bool?

  @Option(name: .long, help: "Format mode: none/swift-format/swiftformat.")
  var format: ToolingFormatMode?

  @Option(name: .long, help: "Header template path.")
  var headerTemplate: String?

  @Option(
    name: .long,
    help:
      "Whether to emit companion extension stub files for custom methods/computed properties (true/false)."
  )
  var emitExtensionStubs: Bool?

  @Option(name: .long, help: "Whether to generate a convenience init (true/false).")
  var generateInit: Bool?

  @Option(name: .long, help: "Relationship setter policy: none/warning/plain.")
  var relationshipSetterPolicy: ToolingRelationshipSetterPolicy?

  @Option(name: .long, help: "Relationship count policy: none/warning/plain.")
  var relationshipCountPolicy: ToolingRelationshipCountPolicy?

  @Option(name: .long, help: "Decode failure policy: fallbackToDefaultValue/debugAssertNil.")
  var defaultDecodeFailurePolicy: ToolingDecodeFailurePolicy?

  @Option(name: .long, help: "Path to JSON config file.")
  var config: String?

  mutating func run() throws {
    let request: GenerateRequest
    do {
      request = try GenerateCommandSupport.makeRequest(from: self)
    } catch let failure as ToolingFailure {
      try fail(failure)
    }

    let result: GenerateResult
    do {
      result = try GenerateService.run(request)
      try GenerateCommandSupport.runFormatterIfNeeded(mode: request.format, result: result)
    } catch let failure as ToolingFailure {
      try fail(failure)
    }

    GenerateCommandSupport.emitResult(result)
  }
}
