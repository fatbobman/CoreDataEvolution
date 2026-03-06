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

struct ValidateCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "validate",
    abstract: "Validate model/code mapping drift."
  )

  @Option(name: .long, help: "Path to source model (.xcdatamodeld/.xcdatamodel).")
  var modelPath: String?

  @Option(name: .long, help: "Specific model version name. Defaults to current/latest.")
  var modelVersion: String?

  @Option(name: .long, help: "Path to momc binary.")
  var momcBin: String?

  @Option(name: .long, help: "Source directory containing generated/model code.")
  var sourceDir: String?

  @Option(name: .long, help: "Swift module name.")
  var moduleName: String?

  @Option(name: .long, help: "Expected access level: internal/public.")
  var accessLevel: ToolingAccessLevel?

  @Option(
    name: .long,
    help: "Whether exact validation should expect a single generated file (true/false).")
  var singleFile: Bool?

  @Option(
    name: .long,
    help: "Whether exact validation should expect split-by-entity output (true/false).")
  var splitByEntity: Bool?

  @Option(name: .long, help: "Header template path used during generation.")
  var headerTemplate: String?

  @Option(
    name: .long,
    help: "Whether generated source is expected to include a convenience init (true/false).")
  var generateInit: Bool?

  @Option(name: .long, help: "Expected relationship setter policy: none/warning/plain.")
  var relationshipSetterPolicy: ToolingRelationshipSetterPolicy?

  @Option(name: .long, help: "Expected relationship count policy: none/warning/plain.")
  var relationshipCountPolicy: ToolingRelationshipCountPolicy?

  @Option(
    name: .long, help: "Expected decode failure policy: fallbackToDefaultValue/debugAssertNil.")
  var defaultDecodeFailurePolicy: ToolingDecodeFailurePolicy?

  @Option(name: .long, help: "Comma-separated include glob patterns.")
  var include: String?

  @Option(name: .long, help: "Comma-separated exclude glob patterns.")
  var exclude: String?

  @Option(
    name: .long,
    help:
      "Validation level: conformance/exact. Default: conformance; exact expects unchanged managed files."
  )
  var level: ToolingValidationLevel?

  @Option(name: .long, help: "Report format: text/json/sarif.")
  var report: ToolingReportFormat?

  @Option(name: .long, help: "Whether to treat warnings as errors (true/false).")
  var failOnWarning: Bool?

  @Option(name: .long, help: "Maximum issues to report.")
  var maxIssues: Int?

  @Option(name: .long, help: "Path to JSON config file.")
  var config: String?

  mutating func run() throws {
    let request: ValidateRequest
    do {
      request = try ValidateCommandSupport.makeRequest(from: self)
    } catch let failure as ToolingFailure {
      try fail(failure)
    }

    let result: ValidateResult
    do {
      result = try ValidateService.run(request)
    } catch let failure as ToolingFailure {
      try fail(failure)
    }

    do {
      try ValidateCommandSupport.emitResult(result, report: request.report)
    } catch let failure as ToolingFailure {
      try fail(failure)
    }

    if let failure = ValidateCommandSupport.failureIfNeeded(
      for: result,
      failOnWarning: request.failOnWarning
    ) {
      try fail(failure)
    }
  }
}
