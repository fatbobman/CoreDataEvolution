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
    let relationshipRules = ToolingRelationshipRules(
      entities: [
        "Item": [
          "tags": .init(swiftName: "labels")
        ]
      ]
    )
    let compositionRules = ToolingCompositionRules(
      types: [
        "ItemLocation": [
          "lat": .init(swiftName: "latitude"),
          "lng": .init(swiftName: "longitude"),
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
      relationshipRules: relationshipRules,
      compositionRules: compositionRules,
      accessLevel: .internal,
      singleFile: false,
      splitByEntity: true,
      overwrite: ToolingOverwriteMode.none,
      cleanStale: false,
      dryRun: false,
      format: .swiftFormat,
      headerTemplate: nil,
      generateInit: false,
      defaultDecodeFailurePolicy: .fallbackToDefaultValue
    )
    var overrides = GenerateRequestOverrides()
    overrides.modelVersion = "V2"
    overrides.accessLevel = .public
    overrides.overwrite = .all
    overrides.generateInit = true

    let request = try GenerateRequest(
      config: configured,
      overrides: overrides
    )

    #expect(request.modelPath.hasSuffix("/Models/AppModel.xcdatamodeld"))
    #expect(request.modelVersion == "V2")
    #expect(request.typeMappings[coreDataType: "Integer 64"]?.swiftType == "Int")
    #expect(request.typeMappings[coreDataType: "UUID"]?.swiftType == "UUID")
    #expect(request.attributeRules == attributeRules)
    #expect(request.relationshipRules == relationshipRules)
    #expect(request.compositionRules == compositionRules)
    #expect(request.accessLevel == .public)
    #expect(request.overwrite == .all)
    #expect(request.generateInit)
    #expect(request.outputDir.hasSuffix("/Generated/CoreDataEvolution"))
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
          "config_blob": .init(
            swiftType: "ItemConfig",
            storageMethod: .codable,
            ignoreOptionality: true
          ),
        ]
      ]
    )
    let relationshipRules = ToolingRelationshipRules(
      entities: [
        "Tag": [
          "items": .init(swiftName: "linkedItems")
        ]
      ]
    )
    let compositionRules = ToolingCompositionRules(
      types: [
        "ItemLocation": [
          "lat": .init(swiftName: "latitude")
        ]
      ]
    )
    let config = ValidateTemplate(
      modelPath: "Models/AppModel.xcdatamodeld",
      modelVersion: nil,
      momcBin: nil,
      sourceDir: "Sources/AppModels",
      moduleName: "AppModels",
      typeMappings: typeMappings,
      attributeRules: attributeRules,
      relationshipRules: relationshipRules,
      compositionRules: compositionRules,
      accessLevel: .internal,
      singleFile: false,
      splitByEntity: true,
      headerTemplate: nil,
      generateInit: false,
      defaultDecodeFailurePolicy: .fallbackToDefaultValue,
      include: [],
      exclude: [],
      level: .conformance,
      report: .text,
      failOnWarning: false,
      maxIssues: 200
    )
    let request = try ValidateRequest(
      config: config
    )

    #expect(request.modelPath.hasSuffix("/Models/AppModel.xcdatamodeld"))
    #expect(request.sourceDir.hasSuffix("/Sources/AppModels"))
    #expect(request.typeMappings[coreDataType: "Integer 64"]?.swiftType == "Int")
    #expect(request.typeMappings[coreDataType: "Date"]?.swiftType == "Date")
    #expect(request.attributeRules == attributeRules)
    #expect(request.attributeRules[entity: "Item"]["config_blob"]?.ignoreOptionality == true)
    #expect(request.relationshipRules == relationshipRules)
    #expect(request.compositionRules == compositionRules)
    #expect(request.accessLevel == .internal)
    #expect(request.singleFile == false)
    #expect(request.splitByEntity == true)
    #expect(request.headerTemplate == nil)
    #expect(request.defaultDecodeFailurePolicy == .fallbackToDefaultValue)
    #expect(request.level == .conformance)
    #expect(request.report == .text)
    #expect(request.maxIssues == 200)
  }

  @Test("config loader decodes validate attribute optionality ignore")
  func configLoaderDecodesValidateAttributeOptionalityIgnore() throws {
    let data = """
      {
        "$schemaVersion": 1,
        "validate": {
          "modelPath": "Models/AppModel.xcdatamodeld",
          "sourceDir": "Sources/AppModels",
          "moduleName": "AppModels",
          "attributeRules": {
            "Item": {
              "title": {
                "ignoreOptionality": true
              }
            }
          }
        }
      }
      """.data(using: .utf8)!

    let template = try loadToolingConfigTemplate(from: data)

    #expect(
      template.validate?.attributeRules?.entities["Item"]?["title"]?.ignoreOptionality == true
    )
  }

  @Test("generate request resolves header template relative to config directory")
  func generateRequestResolvesHeaderTemplateFromConfigDirectory() throws {
    let temporaryDirectory = makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let headerURL = temporaryDirectory.appendingPathComponent("header.txt")
    try "// HEADER".write(to: headerURL, atomically: true, encoding: .utf8)

    let config = GenerateTemplate(
      modelPath: "Models/AppModel.xcdatamodeld",
      modelVersion: nil,
      momcBin: nil,
      outputDir: "Generated/CoreDataEvolution",
      moduleName: "AppModels",
      typeMappings: nil,
      attributeRules: nil,
      accessLevel: .internal,
      singleFile: false,
      splitByEntity: true,
      overwrite: ToolingOverwriteMode.none,
      cleanStale: false,
      dryRun: false,
      format: ToolingFormatMode.none,
      headerTemplate: "header.txt",
      generateInit: false,
      defaultDecodeFailurePolicy: .fallbackToDefaultValue
    )

    let request = try GenerateRequest(
      config: config,
      configDirectory: temporaryDirectory
    )

    #expect(request.headerTemplate == "// HEADER")
  }

  private func makeTemporaryDirectory() -> URL {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("CoreDataEvolutionToolingCoreTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }
}
