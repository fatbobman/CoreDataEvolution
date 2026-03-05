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
import Foundation

@main
struct CDETool: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "cde-tool",
    abstract: "CoreDataEvolution tooling CLI.",
    subcommands: [
      GenerateCommand.self,
      ValidateCommand.self,
      InspectCommand.self,
      InitConfigCommand.self,
    ]
  )
}

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
  var accessLevel: String = "internal"

  @Flag(name: .long, help: "Generate a single output file.")
  var singleFile = false

  @Flag(name: .long, inversion: .prefixedNo, help: "Split outputs by entity.")
  var splitByEntity = true

  @Option(name: .long, help: "Overwrite mode: none/changed/all.")
  var overwrite: String = "none"

  @Flag(name: .long, help: "Clean stale generated files in output directory.")
  var cleanStale = false

  @Flag(name: .long, help: "Preview changes without writing files.")
  var dryRun = false

  @Option(name: .long, help: "Format mode: none/swift-format.")
  var format: String = "none"

  @Option(name: .long, help: "Header template path.")
  var headerTemplate: String?

  @Flag(name: .long, help: "Generate convenience init.")
  var generateInit = false

  @Option(name: .long, help: "Relationship setter policy: none/warning/plain.")
  var relationshipSetterPolicy: String = "warning"

  @Option(name: .long, help: "Relationship count policy: none/warning/plain.")
  var relationshipCountPolicy: String = "none"

  @Option(name: .long, help: "Decode failure policy: fallbackToDefaultValue/debugAssertNil.")
  var defaultDecodeFailurePolicy: String = "fallbackToDefaultValue"

  @Option(name: .long, help: "Path to JSON config file.")
  var config: String?

  mutating func run() throws {
    try failUser(
      code: "CLI-NOT-IMPLEMENTED",
      message: "generate is not implemented yet."
    )
  }
}

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

struct InspectCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "inspect",
    abstract: "Inspect parsed model IR (work in progress)."
  )

  @Option(name: .long, help: "Path to model (.xcdatamodeld/.xcdatamodel/.momd).")
  var modelPath: String

  @Option(name: .long, help: "Specific model version name. Defaults to current/latest.")
  var modelVersion: String?

  @Option(name: .long, help: "Path to JSON config file.")
  var config: String?

  mutating func run() throws {
    try failUser(
      code: "CLI-NOT-IMPLEMENTED",
      message: "inspect is not implemented yet."
    )
  }
}

struct InitConfigCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "init-config",
    abstract: "Export a default JSON config template."
  )

  enum Preset: String, ExpressibleByArgument {
    case minimal
    case full
  }

  @Option(name: .long, help: "Output config file path.")
  var output: String?

  @Flag(name: .long, help: "Print config JSON to stdout.")
  var stdout = false

  @Flag(name: .long, help: "Overwrite existing config file.")
  var force = false

  @Option(name: .long, help: "Template preset: minimal/full.")
  var preset: Preset = .full

  mutating func run() throws {
    if stdout, output != nil {
      try failUser(
        code: "CLI-CONFIG-CONFLICT",
        message: "--output and --stdout cannot be used together."
      )
    }

    let template = makeTemplate(preset: preset)
    let data = try encodeJSON(template)

    if stdout {
      guard let text = String(data: data, encoding: .utf8) else {
        try failInternal(
          code: "CLI-JSON-ENCODE-FAILED",
          message: "failed to encode config template as UTF-8."
        )
      }
      print(text)
      return
    }

    let outputPath = output ?? "cde-tool.json"
    let url = URL(fileURLWithPath: outputPath)
    let fm = FileManager.default
    let directory = url.deletingLastPathComponent()
    var isDirectory: ObjCBool = false
    if fm.fileExists(atPath: directory.path, isDirectory: &isDirectory) == false
      || isDirectory.boolValue == false
    {
      try failUser(
        code: "CLI-OUTPUT-DIR-MISSING",
        message: "output directory does not exist: '\(directory.path)'."
      )
    }
    if fm.fileExists(atPath: url.path), force == false {
      try failUser(
        code: "CLI-CONFIG-EXISTS",
        message: "config file already exists at '\(url.path)'. Use --force to overwrite."
      )
    }

    do {
      try data.write(to: url, options: [.atomic])
      print("wrote config template to \(url.path)")
    } catch {
      try failUser(
        code: "CLI-WRITE-DENIED",
        message: "cannot write config file to '\(url.path)' (\(error.localizedDescription))."
      )
    }
  }
}

private struct CDEToolConfigTemplate: Codable {
  let schemaVersion: Int
  let generate: GenerateTemplate?
  let validate: ValidateTemplate?

  enum CodingKeys: String, CodingKey {
    case schemaVersion = "$schemaVersion"
    case generate
    case validate
  }
}

private struct GenerateTemplate: Codable {
  let modelPath: String
  let modelVersion: String?
  let momcBin: String?
  let outputDir: String
  let moduleName: String
  let accessLevel: String?
  let singleFile: Bool?
  let splitByEntity: Bool?
  let overwrite: String?
  let cleanStale: Bool?
  let dryRun: Bool?
  let format: String?
  let headerTemplate: String?
  let generateInit: Bool?
  let relationshipSetterPolicy: String?
  let relationshipCountPolicy: String?
  let defaultDecodeFailurePolicy: String?
}

private struct ValidateTemplate: Codable {
  let modelPath: String
  let modelVersion: String?
  let sourceDir: String
  let moduleName: String
  let include: [String]?
  let exclude: [String]?
  let level: String?
  let report: String?
  let failOnWarning: Bool?
  let maxIssues: Int?
}

private func makeTemplate(preset: InitConfigCommand.Preset) -> CDEToolConfigTemplate {
  switch preset {
  case .minimal:
    return .init(
      schemaVersion: 1,
      generate: .init(
        modelPath: "Models/AppModel.xcdatamodeld",
        modelVersion: nil,
        momcBin: nil,
        outputDir: "Generated/CoreDataEvolution",
        moduleName: "AppModels",
        accessLevel: nil,
        singleFile: nil,
        splitByEntity: nil,
        overwrite: nil,
        cleanStale: nil,
        dryRun: nil,
        format: nil,
        headerTemplate: nil,
        generateInit: nil,
        relationshipSetterPolicy: nil,
        relationshipCountPolicy: nil,
        defaultDecodeFailurePolicy: nil
      ),
      validate: .init(
        modelPath: "Models/AppModel.xcdatamodeld",
        modelVersion: nil,
        sourceDir: "Sources/AppModels",
        moduleName: "AppModels",
        include: nil,
        exclude: nil,
        level: nil,
        report: nil,
        failOnWarning: nil,
        maxIssues: nil
      )
    )
  case .full:
    return .init(
      schemaVersion: 1,
      generate: .init(
        modelPath: "Models/AppModel.xcdatamodeld",
        modelVersion: nil,
        momcBin: nil,
        outputDir: "Generated/CoreDataEvolution",
        moduleName: "AppModels",
        accessLevel: "internal",
        singleFile: false,
        splitByEntity: true,
        overwrite: "none",
        cleanStale: false,
        dryRun: false,
        format: "swift-format",
        headerTemplate: nil,
        generateInit: false,
        relationshipSetterPolicy: "warning",
        relationshipCountPolicy: "none",
        defaultDecodeFailurePolicy: "fallbackToDefaultValue"
      ),
      validate: .init(
        modelPath: "Models/AppModel.xcdatamodeld",
        modelVersion: nil,
        sourceDir: "Sources/AppModels",
        moduleName: "AppModels",
        include: [],
        exclude: [],
        level: "quick",
        report: "text",
        failOnWarning: false,
        maxIssues: 200
      )
    )
  }
}

private func encodeJSON<T: Encodable>(_ value: T) throws -> Data {
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
  return try encoder.encode(value)
}

private func failUser(code: String, message: String, hint: String? = nil) throws -> Never {
  emitError(code: code, message: message, hint: hint)
  throw ExitCode(1)
}

private func failInternal(code: String, message: String, hint: String? = nil) throws -> Never {
  emitError(code: code, message: message, hint: hint)
  throw ExitCode(2)
}

private func emitError(code: String, message: String, hint: String?) {
  fputs("error[\(code)]: \(message)\n", stderr)
  if let hint {
    fputs("hint: \(hint)\n", stderr)
  }
}
