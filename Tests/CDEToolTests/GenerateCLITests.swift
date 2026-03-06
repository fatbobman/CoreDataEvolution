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

@Suite("CDETool Generate CLI Tests")
struct GenerateCLITests {
  @Test("generate dry-run reports planned writes from config")
  func generateDryRunReportsPlannedWritesFromConfig() throws {
    let modelURL = try makeToolingSourceModelFixture()
    defer { try? FileManager.default.removeItem(at: modelURL.deletingLastPathComponent()) }

    let outputDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("CDEToolTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: outputDirectory) }

    let configURL = try writeToolingConfig(
      .init(
        schemaVersion: toolingSupportedSchemaVersion,
        generate: .init(
          modelPath: modelURL.path,
          modelVersion: nil,
          momcBin: nil,
          outputDir: outputDirectory.path,
          moduleName: "AppModels",
          typeMappings: makeDefaultToolingTypeMappings(),
          attributeRules: makeIntegrationAttributeRules(),
          accessLevel: .internal,
          singleFile: false,
          splitByEntity: true,
          overwrite: ToolingOverwriteMode.none,
          cleanStale: false,
          dryRun: true,
          format: ToolingFormatMode.none,
          headerTemplate: nil,
          emitExtensionStubs: false,
          generateInit: true,
          relationshipSetterPolicy: .plain,
          relationshipCountPolicy: .warning,
          defaultDecodeFailurePolicy: .debugAssertNil
        ),
        validate: nil
      ),
      fileName: "generate.json"
    )
    defer { try? FileManager.default.removeItem(at: configURL.deletingLastPathComponent()) }

    let result = try runTool([
      "generate",
      "--config", configURL.path,
    ])

    #expect(result.exitCode == 0)
    #expect(result.stdout.contains("would create: CDEItem+CoreDataEvolution.swift"))
    #expect(result.stdout.contains("would create: CDETag+CoreDataEvolution.swift"))
    #expect(
      FileManager.default.fileExists(
        atPath: outputDirectory.appendingPathComponent("CDEItem+CoreDataEvolution.swift").path)
        == false)
  }

  @Test("generate writes files from direct CLI arguments")
  func generateWritesFilesFromDirectCLIArguments() throws {
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
      "--emit-extension-stubs", "true",
    ])

    #expect(result.exitCode == 0)
    #expect(result.stdout.contains("created: Item+CoreDataEvolution.swift"))
    #expect(result.stdout.contains("created: Item+Extensions.swift"))

    let generatedURL = outputDirectory.appendingPathComponent("Item+CoreDataEvolution.swift")
    let stubURL = outputDirectory.appendingPathComponent("Item+Extensions.swift")
    #expect(FileManager.default.fileExists(atPath: generatedURL.path))
    #expect(FileManager.default.fileExists(atPath: stubURL.path))

    let generatedContents = try String(contentsOf: generatedURL, encoding: .utf8)
    let stubContents = try String(contentsOf: stubURL, encoding: .utf8)
    #expect(generatedContents.contains("// cde-tool:generated"))
    #expect(stubContents.contains("Add methods and computed properties"))
  }

  @Test("generate rejects Xcode code generation source models")
  func generateRejectsXcodeCodeGenerationSourceModels() throws {
    let modelURL = try makeToolingSourceModelFixture(stripCodeGenerationType: false)
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
    ])

    #expect(result.exitCode == 1)
    #expect(result.stderr.contains("error[TOOL-CONFIG-INVALID]"))
  }
}
