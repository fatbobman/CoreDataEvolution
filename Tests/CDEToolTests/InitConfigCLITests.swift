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

@Suite("CDETool Init Config CLI Tests")
struct InitConfigCLITests {
  @Test("init-config writes minimal template to stdout")
  func initConfigWritesMinimalTemplateToStdout() throws {
    let result = try runTool([
      "init-config",
      "--stdout",
      "--preset", "minimal",
    ])

    #expect(result.exitCode == 0)
    #expect(result.stdout.contains("\"$schemaVersion\""))
    #expect(result.stdout.contains("\"generate\""))
    #expect(result.stderr.isEmpty)
  }

  @Test("init-config writes file and rejects overwrite without force")
  func initConfigWritesFileAndRejectsOverwriteWithoutForce() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("CDEToolTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let outputURL = directory.appendingPathComponent("tooling.json")

    let firstResult = try runTool([
      "init-config",
      "--output", outputURL.path,
    ])

    #expect(firstResult.exitCode == 0)
    #expect(FileManager.default.fileExists(atPath: outputURL.path))
    #expect(firstResult.stdout.contains("wrote config template to \(outputURL.path)"))

    let secondResult = try runTool([
      "init-config",
      "--output", outputURL.path,
    ])

    #expect(secondResult.exitCode == 1)
    #expect(secondResult.stderr.contains("error[TOOL-CONFIG-EXISTS]"))
    #expect(secondResult.stderr.contains("Use --force to overwrite."))
  }

  @Test("init-config rejects conflicting stdout and output options")
  func initConfigRejectsConflictingStdoutAndOutput() throws {
    let result = try runTool([
      "init-config",
      "--stdout",
      "--output", "cde-tool.json",
    ])

    #expect(result.exitCode == 1)
    #expect(result.stderr.contains("error[TOOL-CONFIG-CONFLICT]"))
  }
}
