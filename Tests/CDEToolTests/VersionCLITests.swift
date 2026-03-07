//
//  ------------------------------------------------
//  Original project: CoreDataEvolution
//  Created on 2026/3/7 by Fatbobman(东坡肘子)
//  X: @fatbobman
//  Mastodon: @fatbobman@mastodon.social
//  GitHub: @fatbobman
//  Blog: https://fatbobman.com
//  ------------------------------------------------
//  Copyright © 2024-present Fatbobman. All rights reserved.

import Testing

@Suite("CDETool Version CLI Tests")
struct VersionCLITests {
  @Test("--version prints concise version")
  func rootVersionOptionPrintsConciseVersion() throws {
    let result = try runTool(["--version"])

    #expect(result.exitCode == 0)
    #expect(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
  }

  @Test("-v prints detailed version metadata")
  func shortVersionFlagPrintsDetailedMetadata() throws {
    let result = try runTool(["-v"])

    #expect(result.exitCode == 0)
    #expect(result.stdout.contains("cde-tool "))
    #expect(result.stdout.contains("CoreDataEvolution tag:"))
    #expect(result.stdout.contains("commit:"))
    #expect(result.stdout.contains("describe:"))
    #expect(result.stdout.contains("dirty:"))
  }

  @Test("version subcommand prints detailed version metadata")
  func versionSubcommandPrintsDetailedMetadata() throws {
    let result = try runTool(["version"])

    #expect(result.exitCode == 0)
    #expect(result.stdout.contains("cde-tool "))
    #expect(result.stdout.contains("CoreDataEvolution tag:"))
  }
}
