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

@Suite("Tooling Core File Planning Tests")
struct ToolingFilePlanningTests {
  @Test("file planner injects managed marker after header comments")
  func filePlannerInjectsManagedMarker() throws {
    let plan = try ToolingFilePlanner.makeFilePlan(
      from: [
        .init(
          entityName: "Item",
          suggestedFileName: "Item+CoreDataEvolution.swift",
          contents: "// HEADER\n// HEADER 2\n\nimport Foundation\n"
        )
      ],
      outputDir: "/virtual/Generated"
    )

    let contents = try #require(plan.first?.contents)
    #expect(contents.contains(toolingManagedFileMarker))
    #expect(
      contents.contains("// HEADER\n// HEADER 2\n\n// cde-tool:generated\n\nimport Foundation"))
  }

  @Test("file writer respects overwrite modes and stale cleanup")
  func fileWriterRespectsOverwriteAndStaleCleanup() throws {
    let outputDirectory = makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: outputDirectory) }

    let existingURL = outputDirectory.appendingPathComponent("Item+CoreDataEvolution.swift")
    let staleURL = outputDirectory.appendingPathComponent("Old+CoreDataEvolution.swift")
    let manualURL = outputDirectory.appendingPathComponent("Manual.swift")

    try (toolingManagedFileMarker + "\n\nold").write(
      to: existingURL,
      atomically: true,
      encoding: .utf8
    )
    try (toolingManagedFileMarker + "\n\nstale").write(
      to: staleURL,
      atomically: true,
      encoding: .utf8
    )
    try "manual".write(to: manualURL, atomically: true, encoding: .utf8)

    let plan = [
      ToolingGeneratedFilePlan(
        relativePath: "Item+CoreDataEvolution.swift",
        outputPath: existingURL.path,
        contents: toolingManagedFileMarker + "\n\nnew"
      )
    ]

    let result = try ToolingFileWriter.apply(
      plan: plan,
      outputDir: outputDirectory.path,
      overwrite: .changed,
      cleanStale: true,
      dryRun: false
    )

    #expect(
      result.operations.contains(where: {
        $0.kind == .update && $0.relativePath == "Item+CoreDataEvolution.swift"
      }))
    #expect(
      result.operations.contains(where: {
        $0.kind == .delete && $0.relativePath == "Old+CoreDataEvolution.swift"
      }))
    #expect(FileManager.default.fileExists(atPath: staleURL.path) == false)
    #expect(
      try String(contentsOf: existingURL, encoding: .utf8) == toolingManagedFileMarker + "\n\nnew")
    #expect(FileManager.default.fileExists(atPath: manualURL.path))
  }

  @Test("overwrite none rejects existing targets")
  func overwriteNoneRejectsExistingTargets() throws {
    let outputDirectory = makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: outputDirectory) }

    let existingURL = outputDirectory.appendingPathComponent("Item+CoreDataEvolution.swift")
    try "manual".write(to: existingURL, atomically: true, encoding: .utf8)

    do {
      _ = try ToolingFileWriter.apply(
        plan: [
          .init(
            relativePath: "Item+CoreDataEvolution.swift",
            outputPath: existingURL.path,
            contents: toolingManagedFileMarker + "\n\ncontent"
          )
        ],
        outputDir: outputDirectory.path,
        overwrite: .none,
        cleanStale: false,
        dryRun: false
      )
      Issue.record("Expected overwrite=none to reject existing target.")
    } catch let error as ToolingFailure {
      #expect(error.code == .writeDenied)
    }
  }

  private func makeTemporaryDirectory() -> URL {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("CoreDataEvolutionToolingCoreTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }
}
