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

@Suite("Tooling Core Config Template Tests")
struct ConfigTemplateTests {
  @Test("minimal preset keeps only required fields")
  func minimalPresetKeepsOnlyRequiredFields() throws {
    let template = makeDefaultConfigTemplate(preset: .minimal)

    #expect(template.schemaVersion == 1)
    #expect(template.generate?.modelPath == "Models/AppModel.xcdatamodeld")
    #expect(template.generate?.outputDir == "Generated/CoreDataEvolution")
    #expect(template.generate?.moduleName == "AppModels")
    #expect(template.generate?.typeMappings == nil)
    #expect(template.generate?.attributeRules == nil)
    #expect(template.generate?.relationshipSetterPolicy == nil)
    #expect(template.validate?.modelPath == "Models/AppModel.xcdatamodeld")
    #expect(template.validate?.sourceDir == "Sources/AppModels")
    #expect(template.validate?.moduleName == "AppModels")
    #expect(template.validate?.typeMappings == nil)
    #expect(template.validate?.attributeRules == nil)
    #expect(template.validate?.relationshipSetterPolicy == nil)
    #expect(template.validate?.level == nil)
  }

  @Test("full preset includes documented defaults")
  func fullPresetIncludesDocumentedDefaults() throws {
    let template = makeDefaultConfigTemplate(preset: .full)
    let defaultTypeMappings = makeDefaultToolingTypeMappings()

    #expect(template.schemaVersion == 1)
    #expect(template.generate?.typeMappings == defaultTypeMappings)
    #expect(template.generate?.attributeRules == .init())
    #expect(template.generate?.accessLevel == .internal)
    #expect(template.generate?.splitByEntity == true)
    #expect(template.generate?.overwrite == ToolingOverwriteMode.none)
    #expect(template.generate?.format == ToolingFormatMode.none)
    #expect(template.generate?.emitExtensionStubs == false)
    #expect(template.generate?.relationshipSetterPolicy == .warning)
    #expect(template.generate?.relationshipCountPolicy == ToolingRelationshipCountPolicy.none)
    #expect(template.generate?.defaultDecodeFailurePolicy == .fallbackToDefaultValue)
    #expect(template.validate?.typeMappings == defaultTypeMappings)
    #expect(template.validate?.attributeRules == .init())
    #expect(template.validate?.momcBin == nil)
    #expect(template.validate?.relationshipSetterPolicy == .warning)
    #expect(template.validate?.relationshipCountPolicy == ToolingRelationshipCountPolicy.none)
    #expect(template.validate?.defaultDecodeFailurePolicy == .fallbackToDefaultValue)
    #expect(template.validate?.level == .conformance)
    #expect(template.validate?.report == .text)
    #expect(template.validate?.maxIssues == 200)
  }

  @Test("encoded json uses schemaVersion key")
  func encodedJSONUsesSchemaVersionKey() throws {
    let template = makeDefaultConfigTemplate(preset: .full)
    let data = try encodeToolingJSON(template)
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

    #expect(json?["$schemaVersion"] as? Int == 1)
    #expect(json?["schemaVersion"] == nil)
  }
}
