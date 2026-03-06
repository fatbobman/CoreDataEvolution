//
//  ------------------------------------------------
//  Original project: CoreDataEvolution
//  Created on 2026/3/6 by Fatbobman(东坡肘子)
//  X: @fatbobman
//  Mastodon: @fatbobman@mastodon.social
//  GitHub: @fatbobman
//  Blog: https://fatbobman.com
//  ------------------------------------------------
//  Copyright © 2024-present Fatbobman. All rights reserved.

import ArgumentParser
import Testing

@testable import CDETool

@Suite("CDETool Command Parsing Tests")
struct CommandParsingTests {
  @Test("generate command parses boolean and enum options")
  func generateCommandParsesBooleanAndEnumOptions() throws {
    let command = try GenerateCommand.parse([
      "--model-path", "Model.xcdatamodeld",
      "--output-dir", "Generated",
      "--module-name", "AppModels",
      "--single-file", "true",
      "--overwrite", "changed",
      "--format", "swiftformat",
      "--emit-extension-stubs", "true",
    ])

    #expect(command.modelPath == "Model.xcdatamodeld")
    #expect(command.singleFile == true)
    #expect(command.overwrite == .changed)
    #expect(command.format == .swiftformat)
    #expect(command.emitExtensionStubs == true)
  }

  @Test("validate command parses level report and patterns")
  func validateCommandParsesLevelReportAndPatterns() throws {
    let command = try ValidateCommand.parse([
      "--model-path", "Model.xcdatamodeld",
      "--source-dir", "Sources/AppModels",
      "--module-name", "AppModels",
      "--include", "A.swift,B.swift",
      "--exclude", "C.swift",
      "--level", "exact",
      "--report", "sarif",
      "--fail-on-warning", "true",
      "--max-issues", "10",
    ])

    #expect(command.level == .exact)
    #expect(command.report == .sarif)
    #expect(command.include == "A.swift,B.swift")
    #expect(command.exclude == "C.swift")
    #expect(command.failOnWarning == true)
    #expect(command.maxIssues == 10)
  }

  @Test("init-config command parses preset and flags")
  func initConfigCommandParsesPresetAndFlags() throws {
    let command = try InitConfigCommand.parse([
      "--stdout",
      "--force",
      "--preset", "minimal",
    ])

    #expect(command.stdout)
    #expect(command.force)
    #expect(command.preset == .minimal)
  }

  @Test("bootstrap-config command applies documented defaults")
  func bootstrapConfigCommandAppliesDocumentedDefaults() throws {
    let command = try BootstrapConfigCommand.parse([
      "--model-path", "Model.xcdatamodeld",
    ])

    #expect(command.moduleName == "AppModels")
    #expect(command.outputDir == "Generated/CoreDataEvolution")
    #expect(command.sourceDir == "Sources/AppModels")
    #expect(command.stdout == false)
    #expect(command.force == false)
  }

  @Test("validate command rejects removed legacy level names")
  func validateCommandRejectsLegacyLevelNames() throws {
    do {
      _ = try ValidateCommand.parse([
        "--model-path", "Model.xcdatamodeld",
        "--source-dir", "Sources/AppModels",
        "--module-name", "AppModels",
        "--level", "strict",
      ])
      Issue.record("Expected legacy validation level to fail parsing.")
    } catch {
      #expect(Bool(true))
    }
  }
}
