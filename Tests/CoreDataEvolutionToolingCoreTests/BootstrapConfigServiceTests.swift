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

@Suite("Tooling Core Bootstrap Config Service Tests")
struct BootstrapConfigServiceTests {
  @Test("service builds editable config scaffold from integration model")
  func bootstrapConfigIncludesModelDerivedAttributeRules() throws {
    let repositoryRoot = try findRepositoryRoot()
    let modelPath =
      repositoryRoot
      .appendingPathComponent("Models")
      .appendingPathComponent("Integration")
      .appendingPathComponent("CoreDataEvolutionIntegrationModel.xcdatamodeld")

    let result = try BootstrapConfigService.run(
      .init(
        modelPath: modelPath.path,
        modelVersion: nil,
        momcBin: nil,
        moduleName: "AppModels",
        outputDir: "Generated/CoreDataEvolution",
        sourceDir: "Sources/AppModels"
      )
    )

    let itemRules = try #require(result.template.generate?.attributeRules?.entities["CDEItem"])
    let nameRule = try #require(itemRules["name"])
    #expect(nameRule.swiftName == nil)
    #expect(nameRule.swiftType == nil)
    #expect(nameRule.storageMethod == nil)

    let locationRule = try #require(itemRules["location"])
    #expect(locationRule.swiftName == nil)
    #expect(locationRule.storageMethod == .transformed)

    let json = try #require(String(data: result.jsonData, encoding: .utf8))
    #expect(json.contains("\"attributeRules\""))
    #expect(json.contains("\"typeMappings\""))
    #expect(json.contains("\"location\""))
    #expect(result.diagnostics.isEmpty == false)
  }

  private func findRepositoryRoot(filePath: String = #filePath) throws -> URL {
    var currentURL = URL(fileURLWithPath: filePath).deletingLastPathComponent()
    while currentURL.path != "/" {
      if FileManager.default.fileExists(
        atPath: currentURL.appendingPathComponent("Package.swift").path)
      {
        return currentURL
      }
      currentURL = currentURL.deletingLastPathComponent()
    }

    throw ToolingFailure.runtime(
      .internalError,
      "failed to locate repository root from '\(filePath)'."
    )
  }
}
