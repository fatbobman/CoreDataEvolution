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

@Suite("CDETool Help CLI Tests")
struct HelpCLITests {
  @Test("generate help explains source-model and config override behavior")
  func generateHelpExplainsSourceModelAndConfigOverrideBehavior() throws {
    let result = try runTool([
      "generate",
      "--help",
    ])

    #expect(result.exitCode == 0)
    #expect(result.stdout.contains("Compiled .mom/.momd inputs are not supported."))
    #expect(result.stdout.contains("direct CLI options override config values"))
  }

  @Test("validate help explains exact mode and config override behavior")
  func validateHelpExplainsExactModeAndConfigOverrideBehavior() throws {
    let result = try runTool([
      "validate",
      "--help",
    ])

    #expect(result.exitCode == 0)
    #expect(result.stdout.contains("conformance/exact"))
    #expect(result.stdout.contains("direct CLI options override config values"))
  }

  @Test("inspect help explains generate-section config behavior")
  func inspectHelpExplainsGenerateSectionConfigBehavior() throws {
    let result = try runTool([
      "inspect",
      "--help",
    ])

    #expect(result.exitCode == 0)
    #expect(result.stdout.contains("resolved generation rules"))
    #expect(result.stdout.contains("Reads the generate section"))
  }
}
