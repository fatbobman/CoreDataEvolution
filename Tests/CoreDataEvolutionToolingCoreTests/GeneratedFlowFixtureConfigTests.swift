//
//  ------------------------------------------------
//  Original project: CoreDataEvolution
//  Created on 2026/3/8 by Fatbobman(东坡肘子)
//  X: @fatbobman
//  Mastodon: @fatbobman@mastodon.social
//  GitHub: @fatbobman
//  Blog: https://fatbobman.com
//  ------------------------------------------------
//  Copyright © 2024-present Fatbobman. All rights reserved.

import Foundation
import Testing

@testable import CoreDataEvolutionToolingCore

struct GeneratedFlowFixtureConfigTests {
  @Test("generated flow fixture config decodes")
  func generatedFlowFixtureConfigDecodes() throws {
    let repositoryRoot = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let configURL =
      repositoryRoot
      .appendingPathComponent("Integration")
      .appendingPathComponent("GeneratedFlowFixture")
      .appendingPathComponent("cde-tool.json")

    let template = try loadToolingConfigTemplate(at: configURL)
    #expect(template.generate != nil)
    #expect(template.validate != nil)
  }
}
