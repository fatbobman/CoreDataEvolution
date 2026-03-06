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

@Suite("Tooling Core Config Loading And Merging Tests")
struct ConfigLoadingAndMergingTests {
  @Test("schema version newer than supported is rejected")
  func unsupportedSchemaVersionIsRejected() throws {
    let data = """
      {
        "$schemaVersion": 999,
        "generate": {
          "modelPath": "Models/AppModel.xcdatamodeld",
          "outputDir": "Generated/CoreDataEvolution",
          "moduleName": "AppModels"
        }
      }
      """.data(using: .utf8)!

    do {
      _ = try loadToolingConfigTemplate(from: data)
      Issue.record("Expected schema validation to throw.")
    } catch let error as ToolingFailure {
      #expect(error.code == .configSchemaUnsupported)
      #expect(error.exitCode == 1)
    }
  }

  @Test("generate request merges config and cli overrides")
  func generateRequestMergesConfigAndCLIOverrides() throws {
    let config = makeDefaultConfigTemplate(preset: .full)
    let typeMappings = ToolingTypeMappings(
      coreDataTypes: [
        "Integer 64": .init(swiftType: "Int"),
        "Float": .init(swiftType: "Double"),
      ]
    )
    let attributeRules = ToolingAttributeRules(
      entities: [
        "Item": [
          "name": .init(swiftName: "title"),
          "status_raw": .init(swiftType: "ItemStatus", storageMethod: .raw),
          "config_blob": .init(swiftType: "ItemConfig", storageMethod: .codable),
        ]
      ]
    )
    let configured = GenerateTemplate(
      modelPath: "Models/AppModel.xcdatamodeld",
      modelVersion: config.generate?.modelVersion,
      momcBin: config.generate?.momcBin,
      outputDir: "Generated/CoreDataEvolution",
      moduleName: "AppModels",
      typeMappings: typeMappings,
      attributeRules: attributeRules,
      accessLevel: .internal,
      singleFile: false,
      splitByEntity: true,
      overwrite: ToolingOverwriteMode.none,
      cleanStale: false,
      dryRun: false,
      format: .swiftFormat,
      headerTemplate: nil,
      generateInit: false,
      relationshipSetterPolicy: .warning,
      relationshipCountPolicy: ToolingRelationshipGenerationPolicy.none,
      defaultDecodeFailurePolicy: .fallbackToDefaultValue
    )
    var overrides = GenerateRequestOverrides()
    overrides.modelVersion = "V2"
    overrides.accessLevel = .public
    overrides.overwrite = .all
    overrides.generateInit = true

    let request = GenerateRequest(
      config: configured,
      overrides: overrides
    )

    #expect(request.modelPath == "Models/AppModel.xcdatamodeld")
    #expect(request.modelVersion == "V2")
    #expect(request.typeMappings == typeMappings)
    #expect(request.attributeRules == attributeRules)
    #expect(request.accessLevel == .public)
    #expect(request.overwrite == .all)
    #expect(request.generateInit)
    #expect(request.relationshipSetterPolicy == .warning)
  }

  @Test("validate request merges config defaults when overrides are empty")
  func validateRequestUsesConfigDefaults() throws {
    let typeMappings = ToolingTypeMappings(
      coreDataTypes: [
        "Integer 64": .init(swiftType: "Int"),
        "Float": .init(swiftType: "Double"),
      ]
    )
    let attributeRules = ToolingAttributeRules(
      entities: [
        "Item": [
          "name": .init(swiftName: "title"),
          "config_blob": .init(swiftType: "ItemConfig", storageMethod: .codable),
        ]
      ]
    )
    let config = ValidateTemplate(
      modelPath: "Models/AppModel.xcdatamodeld",
      modelVersion: nil,
      sourceDir: "Sources/AppModels",
      moduleName: "AppModels",
      typeMappings: typeMappings,
      attributeRules: attributeRules,
      include: [],
      exclude: [],
      level: .quick,
      report: .text,
      failOnWarning: false,
      maxIssues: 200
    )
    let request = ValidateRequest(
      config: config
    )

    #expect(request.modelPath == "Models/AppModel.xcdatamodeld")
    #expect(request.sourceDir == "Sources/AppModels")
    #expect(request.typeMappings == typeMappings)
    #expect(request.attributeRules == attributeRules)
    #expect(request.level == .quick)
    #expect(request.report == .text)
    #expect(request.maxIssues == 200)
  }
}
