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
}
