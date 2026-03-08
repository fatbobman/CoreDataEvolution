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
    let modelPath = try makeToolingSourceModelFixture()
    defer { try? FileManager.default.removeItem(at: modelPath.deletingLastPathComponent()) }

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
    let itemRelationshipRules = try #require(
      result.template.generate?.relationshipRules?.entities["CDEItem"])
    #expect(result.template.generate?.compositionRules == .init())
    #expect(result.template.validate?.compositionRules == .init())
    #expect(
      result.template.generate?.modelVersion == "CoreDataEvolutionIntegrationModel.xcdatamodel")
    #expect(
      result.template.validate?.modelVersion == "CoreDataEvolutionIntegrationModel.xcdatamodel")
    #expect(result.template.validate?.accessLevel == .internal)
    #expect(result.template.validate?.singleFile == false)
    #expect(result.template.validate?.splitByEntity == true)
    #expect(result.template.validate?.headerTemplate == nil)
    #expect(result.template.generate?.emitExtensionStubs == false)
    #expect(result.template.validate?.generateInit == false)
    #expect(result.template.validate?.defaultDecodeFailurePolicy == .fallbackToDefaultValue)
    let nameRule = try #require(itemRules["name"])
    #expect(nameRule.swiftName == nil)
    #expect(nameRule.swiftType == nil)
    #expect(nameRule.storageMethod == nil)

    let locationRule = try #require(itemRules["location"])
    #expect(locationRule.swiftName == nil)
    #expect(locationRule.storageMethod == nil)
    #expect(itemRelationshipRules["tag"]?.swiftName == nil)

    let json = try #require(String(data: result.jsonData, encoding: .utf8))
    #expect(json.contains("\"attributeRules\""))
    #expect(json.contains("\"relationshipRules\""))
    #expect(json.contains("\"compositionRules\""))
    #expect(json.contains("\"typeMappings\""))
    #expect(json.contains("\"location\""))
    #expect(result.diagnostics.isEmpty == false)
    #expect(result.diagnostics.contains(where: { $0.message.contains("Binary -> Data") }))
  }

}
