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

struct ValidateCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "validate",
    abstract: "Validate model/code mapping drift."
  )

  @Option(name: .long, help: "Path to model (.xcdatamodeld/.xcdatamodel/.momd).")
  var modelPath: String

  @Option(name: .long, help: "Specific model version name. Defaults to current/latest.")
  var modelVersion: String?

  @Option(name: .long, help: "Source directory containing generated/model code.")
  var sourceDir: String

  @Option(name: .long, help: "Swift module name.")
  var moduleName: String

  @Option(name: .long, parsing: .upToNextOption, help: "Include glob patterns.")
  var include: [String] = []

  @Option(name: .long, parsing: .upToNextOption, help: "Exclude glob patterns.")
  var exclude: [String] = []

  @Option(name: .long, help: "Validation level: quick/strict.")
  var level: String = "quick"

  @Option(name: .long, help: "Report format: text/json/sarif.")
  var report: String = "text"

  @Flag(name: .long, help: "Treat warnings as errors.")
  var failOnWarning = false

  @Option(name: .long, help: "Maximum issues to report.")
  var maxIssues = 200

  @Option(name: .long, help: "Path to JSON config file.")
  var config: String?

  mutating func run() throws {
    try failUser(
      code: "CLI-NOT-IMPLEMENTED",
      message: "validate is not implemented yet."
    )
  }
}
