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

@Suite("CDETool Inspect CLI Tests")
struct InspectCLITests {
  @Test("inspect prints IR json for source model")
  func inspectPrintsIRJSONForSourceModel() throws {
    let modelURL = try makeToolingSourceModelFixture()
    defer { try? FileManager.default.removeItem(at: modelURL.deletingLastPathComponent()) }

    let result = try runTool([
      "inspect",
      "--model-path", modelURL.path,
    ])

    #expect(result.exitCode == 0)
    #expect(result.stdout.contains("\"entities\""))
    #expect(result.stdout.contains("\"CDEItem\""))
    #expect(result.stderr.contains("warning["))
  }

  @Test("inspect rejects config files without generate section")
  func inspectRejectsConfigWithoutGenerateSection() throws {
    let configURL = try writeToolingConfig(
      .init(
        schemaVersion: toolingSupportedSchemaVersion,
        generate: nil,
        validate: nil
      ),
      fileName: "inspect.json"
    )
    defer { try? FileManager.default.removeItem(at: configURL.deletingLastPathComponent()) }

    let modelURL = try makeToolingSourceModelFixture()
    defer { try? FileManager.default.removeItem(at: modelURL.deletingLastPathComponent()) }

    let result = try runTool([
      "inspect",
      "--model-path", modelURL.path,
      "--config", configURL.path,
    ])

    #expect(result.exitCode == 1)
    #expect(result.stderr.contains("error[TOOL-CONFIG-INVALID]"))
  }

  @Test("inspect rejects Xcode code generation source models")
  func inspectRejectsXcodeCodeGenerationSourceModels() throws {
    let modelURL = try makeToolingSourceModelFixture(stripCodeGenerationType: false)
    defer { try? FileManager.default.removeItem(at: modelURL.deletingLastPathComponent()) }

    let result = try runTool([
      "inspect",
      "--model-path", modelURL.path,
    ])

    #expect(result.exitCode == 1)
    #expect(result.stderr.contains("error[TOOL-CONFIG-INVALID]"))
  }
}
