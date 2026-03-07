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

@Suite("Tooling Core Init Config Service Tests")
struct InitConfigServiceTests {
  @Test("service renders full preset as json")
  func serviceRendersFullPreset() throws {
    let result = try InitConfigService.run(.init(preset: .full))
    let text = try #require(String(data: result.jsonData, encoding: .utf8))

    #expect(result.template.schemaVersion == toolingSupportedSchemaVersion)
    #expect(result.diagnostics.isEmpty)
    #expect(text.contains("\"$schemaVersion\""))
    #expect(text.contains("\"typeMappings\""))
    #expect(text.contains("\"attributeRules\""))
    #expect(text.contains("\"relationshipRules\""))
    #expect(text.contains("\"Integer 64\""))
    #expect(text.contains("\"relationshipSetterPolicy\""))
    #expect(text.contains("\"warning\""))
  }
}
