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

import Foundation
import Testing

@Suite("CDETool Command Parsing Tests")
struct CommandParsingTests {
  @Test("generate command accepts current boolean and enum option spellings")
  func generateCommandAcceptsBooleanAndEnumOptions() throws {
    let modelURL = try makeMinimalSourceModelFixture(entityName: "Item")
    defer { try? FileManager.default.removeItem(at: modelURL.deletingLastPathComponent()) }

    let outputDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("CDEToolTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: outputDirectory) }

    let result = try runTool([
      "generate",
      "--model-path", modelURL.path,
      "--output-dir", outputDirectory.path,
      "--module-name", "AppModels",
      "--single-file", "true",
      "--split-by-entity", "false",
      "--overwrite", "changed",
      "--format", "none",
      "--emit-extension-stubs", "true",
      "--dry-run", "true",
    ])

    #expect(result.exitCode == 0)
    #expect(result.stdout.contains("would create: AppModels+CoreDataEvolution.swift"))
    #expect(result.stdout.contains("would create: Item+Extensions.swift"))
  }

  @Test("validate command accepts current level and report spellings")
  func validateCommandAcceptsCurrentLevelAndReportOptions() throws {
    let modelURL = try makeMinimalSourceModelFixture(entityName: "Item")
    defer { try? FileManager.default.removeItem(at: modelURL.deletingLastPathComponent()) }

    let sourceDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("CDEToolTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: sourceDirectory) }

    let generateResult = try runTool([
      "generate",
      "--model-path", modelURL.path,
      "--output-dir", sourceDirectory.path,
      "--module-name", "AppModels",
    ])
    #expect(generateResult.exitCode == 0)

    let result = try runTool([
      "validate",
      "--model-path", modelURL.path,
      "--source-dir", sourceDirectory.path,
      "--module-name", "AppModels",
      "--level", "conformance",
      "--report", "json",
      "--fail-on-warning", "false",
      "--max-issues", "10",
    ])

    #expect(result.exitCode == 0)
    #expect(result.stdout.contains("\"errorCount\""))
    #expect(result.stdout.contains("\"warningCount\""))
  }

  @Test("validate command rejects removed legacy level names")
  func validateCommandRejectsLegacyLevelNames() throws {
    let fixture = try makeGeneratedSourceFixture()
    defer { fixture.cleanUp() }

    let result = try runTool([
      "validate",
      "--model-path", fixture.modelPath,
      "--source-dir", fixture.sourceDirectory.path,
      "--module-name", "AppModels",
      "--level", "strict",
    ])

    #expect(result.exitCode != 0)
    #expect(result.stderr.contains("strict"))
    #expect(result.stderr.localizedCaseInsensitiveContains("invalid"))
  }
}
