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

import CoreDataEvolutionToolingCore
import Foundation
import Testing

@Suite("CDETool Bootstrap Config CLI Tests")
struct BootstrapConfigCLITests {
  @Test("bootstrap-config emits editable scaffold to stdout")
  func bootstrapConfigEmitsScaffoldToStdout() throws {
    let modelURL = try makeToolingSourceModelFixture()
    defer { try? FileManager.default.removeItem(at: modelURL.deletingLastPathComponent()) }

    let result = try runTool([
      "bootstrap-config",
      "--model-path", modelURL.path,
      "--stdout",
    ])

    #expect(result.exitCode == 0)
    #expect(result.stdout.contains("\"attributeRules\""))
    #expect(result.stdout.contains("\"typeMappings\""))
    #expect(result.stdout.contains("\"modelVersion\""))
  }

  @Test("bootstrap-config rejects conflicting stdout and output options")
  func bootstrapConfigRejectsConflictingStdoutAndOutput() throws {
    let modelURL = try makeToolingSourceModelFixture()
    defer { try? FileManager.default.removeItem(at: modelURL.deletingLastPathComponent()) }

    let result = try runTool([
      "bootstrap-config",
      "--model-path", modelURL.path,
      "--stdout",
      "--output", "cde-tool.json",
    ])

    #expect(result.exitCode == 1)
    #expect(result.stderr.contains("error[TOOL-CONFIG-CONFLICT]"))
  }

  @Test("bootstrap-config rejects Xcode code generation source models")
  func bootstrapConfigRejectsXcodeCodeGenerationSourceModels() throws {
    let modelURL = try makeToolingSourceModelFixture(stripCodeGenerationType: false)
    defer { try? FileManager.default.removeItem(at: modelURL.deletingLastPathComponent()) }

    let result = try runTool([
      "bootstrap-config",
      "--model-path", modelURL.path,
      "--stdout",
    ])

    #expect(result.exitCode == 1)
    #expect(result.stderr.contains("error[TOOL-CONFIG-INVALID]"))
    #expect(result.stderr.contains("must not use Xcode code generation mode"))
  }

  @Test("bootstrap-config rewrites paths and preserves explicit mappings in output config")
  func bootstrapConfigRewritesPathsRelativeToOutputConfig() throws {
    let modelURL = try makeToolingSourceModelFixture()
    defer { try? FileManager.default.removeItem(at: modelURL.deletingLastPathComponent()) }

    let outputDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("CDEToolTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
      .appendingPathComponent("Configs", isDirectory: true)
    try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: outputDirectory.deletingLastPathComponent()) }

    let configURL = outputDirectory.appendingPathComponent("cde-tool.json")
    let result = try runTool([
      "bootstrap-config",
      "--model-path", modelURL.path,
      "--style", "explicit",
      "--output-dir", "Generated/CoreDataEvolution",
      "--source-dir", "Sources/AppModels",
      "--output", configURL.path,
    ])

    #expect(result.exitCode == 0)

    let template = try JSONDecoder().decode(
      ToolingConfigTemplate.self,
      from: Data(contentsOf: configURL)
    )
    let generate = try #require(template.generate)
    let validate = try #require(template.validate)
    let repositoryURL = try repositoryRoot()
    let generatedOutputURL = repositoryURL.appendingPathComponent(
      "Generated/CoreDataEvolution",
      isDirectory: true
    )
    let sourceOutputURL = repositoryURL.appendingPathComponent(
      "Sources/AppModels",
      isDirectory: true
    )

    #expect(generate.modelPath == makeRelativePath(from: outputDirectory, to: modelURL))
    #expect(generate.outputDir == makeRelativePath(from: outputDirectory, to: generatedOutputURL))
    #expect(validate.sourceDir == makeRelativePath(from: outputDirectory, to: sourceOutputURL))
    #expect(generate.relationshipRules?.entities["CDEItem"]?["tag"]?.swiftName == "tag")
    #expect(validate.relationshipRules?.entities["CDEItem"]?["tag"]?.swiftName == "tag")
    #expect(generate.compositionRules?.types["CDEItemLocation"]?["x"]?.swiftName == "x")
    #expect(validate.compositionRules?.types["CDEItemLocation"]?["x"]?.swiftName == "x")
  }

  @Test("bootstrap-config can emit explicit default mappings")
  func bootstrapConfigCanEmitExplicitDefaultMappings() throws {
    let modelURL = try makeToolingSourceModelFixture()
    defer { try? FileManager.default.removeItem(at: modelURL.deletingLastPathComponent()) }

    let result = try runTool([
      "bootstrap-config",
      "--model-path", modelURL.path,
      "--style", "explicit",
      "--stdout",
    ])

    #expect(result.exitCode == 0)
    #expect(result.stdout.contains("\"swiftName\" : \"name\""))
    #expect(result.stdout.contains("\"storageMethod\" : \"default\""))
    #expect(result.stdout.contains("\"CDEItemLocation\""))
  }
}
