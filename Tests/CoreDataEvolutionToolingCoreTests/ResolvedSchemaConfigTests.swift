//
//  ------------------------------------------------
//  Original project: CoreDataEvolution
//  Created on 2026/03/10 by Fatbobman(东坡肘子)
//  X: @fatbobman
//  Mastodon: @fatbobman@mastodon.social
//  GitHub: @fatbobman
//  Blog: https://fatbobman.com
//  ------------------------------------------------
//  Copyright © 2024-present Fatbobman. All rights reserved.
//

import CoreData
import Testing

@testable import CoreDataEvolutionToolingCore

struct ResolvedSchemaConfigTests {
  @Test("generate template and request resolve to the same schema config")
  func generateTemplateAndRequestResolveSameConfig() throws {
    let generate = GenerateTemplate(
      modelPath: "Models/AppModel.xcdatamodeld",
      modelVersion: "V2",
      momcBin: nil,
      outputDir: "Sources/Generated",
      moduleName: "AppModels",
      typeMappings: makeDefaultToolingTypeMappings(),
      attributeRules: ToolingAttributeRules(entities: [
        "Item": [
          "name": ToolingAttributeRule(swiftName: "title")
        ]
      ]),
      relationshipRules: ToolingRelationshipRules(entities: [
        "Item": [
          "tag": ToolingRelationshipRule(swiftName: "ownerTag")
        ]
      ]),
      compositionRules: ToolingCompositionRules(types: [
        "GeoPoint": [
          "latitude": ToolingCompositionFieldRule(swiftName: "latitude")
        ]
      ]),
      accessLevel: .public,
      singleFile: false,
      splitByEntity: true,
      overwrite: .changed,
      cleanStale: true,
      dryRun: false,
      format: .swiftformat,
      headerTemplate: nil,
      emitExtensionStubs: true,
      generateInit: false,
      defaultDecodeFailurePolicy: .fallbackToDefaultValue
    )

    let request = try GenerateRequest(
      config: generate,
      overrides: .init(),
      configDirectory: URL(fileURLWithPath: "/tmp")
    )

    let fromTemplate = ToolingResolvedSchemaConfig(generateTemplate: generate)
    let fromRequest = ToolingResolvedSchemaConfig(generateRequest: request)

    #expect(fromRequest == fromTemplate)
  }

  @Test("validate template and request resolve to the same schema config")
  func validateTemplateAndRequestResolveSameConfig() throws {
    let validate = ValidateTemplate(
      modelPath: "Models/AppModel.xcdatamodeld",
      modelVersion: "V3",
      momcBin: "/usr/bin/momc",
      sourceDir: "Sources/AppModels",
      moduleName: "AppModels",
      typeMappings: makeDefaultToolingTypeMappings(),
      attributeRules: ToolingAttributeRules(entities: [
        "Task": [
          "title": ToolingAttributeRule(swiftName: "name")
        ]
      ]),
      relationshipRules: ToolingRelationshipRules(entities: [
        "Task": [
          "project": ToolingRelationshipRule(swiftName: "ownerProject")
        ]
      ]),
      compositionRules: ToolingCompositionRules(types: [
        "Location": [
          "longitude": ToolingCompositionFieldRule(swiftName: "longitude")
        ]
      ]),
      accessLevel: .internal,
      singleFile: false,
      splitByEntity: true,
      headerTemplate: nil,
      generateInit: true,
      defaultDecodeFailurePolicy: .debugAssertNil,
      include: ["Sources/**/*.swift"],
      exclude: ["Tests/**/*.swift"],
      level: .exact,
      report: .json,
      failOnWarning: false,
      maxIssues: 50
    )

    let request = try ValidateRequest(
      config: validate,
      overrides: .init(),
      configDirectory: URL(fileURLWithPath: "/tmp")
    )

    let fromTemplate = ToolingResolvedSchemaConfig(validateTemplate: validate)
    let fromRequest = ToolingResolvedSchemaConfig(validateRequest: request)

    #expect(fromRequest == fromTemplate)
  }

  @Test("resolved schema config validation matches template validation for static rule conflicts")
  func resolvedSchemaConfigValidationMatchesTemplateValidation() {
    let generate = GenerateTemplate(
      modelPath: "Models/AppModel.xcdatamodeld",
      modelVersion: nil,
      momcBin: nil,
      outputDir: "Sources/Generated",
      moduleName: "AppModels",
      typeMappings: nil,
      attributeRules: ToolingAttributeRules(entities: [
        "Item": [
          "payload": ToolingAttributeRule(
            storageMethod: .transformed,
            transformerName: ""
          )
        ]
      ]),
      relationshipRules: nil,
      compositionRules: nil,
      accessLevel: .internal,
      singleFile: false,
      splitByEntity: true,
      overwrite: nil,
      cleanStale: nil,
      dryRun: nil,
      format: nil,
      headerTemplate: nil,
      emitExtensionStubs: nil,
      generateInit: nil,
      defaultDecodeFailurePolicy: nil
    )

    #expect(throws: ToolingFailure.self) {
      try validateToolingConfigTemplate(
        .init(schemaVersion: toolingSupportedSchemaVersion, generate: generate, validate: nil)
      )
    }

    #expect(throws: ToolingFailure.self) {
      try validateResolvedToolingSchemaConfigStatically(
        .init(generateTemplate: generate),
        context: "generate"
      )
    }
  }

  @Test("resolved schema config validation matches model-aware template validation")
  func resolvedSchemaConfigValidationMatchesModelAwareTemplateValidation() throws {
    let model = NSManagedObjectModel()
    let entity = NSEntityDescription()
    entity.name = "Task"
    entity.managedObjectClassName = "Task"

    let title = NSAttributeDescription()
    title.name = "title"
    title.attributeType = .stringAttributeType
    title.isOptional = false
    title.defaultValue = ""

    entity.properties = [title]
    model.entities = [entity]

    let generate = GenerateTemplate(
      modelPath: "Models/AppModel.xcdatamodeld",
      modelVersion: nil,
      momcBin: nil,
      outputDir: "Sources/Generated",
      moduleName: "AppModels",
      typeMappings: nil,
      attributeRules: nil,
      relationshipRules: ToolingRelationshipRules(entities: [
        "Task": [
          "missing": ToolingRelationshipRule(swiftName: "renamed")
        ]
      ]),
      compositionRules: nil,
      accessLevel: nil,
      singleFile: nil,
      splitByEntity: nil,
      overwrite: nil,
      cleanStale: nil,
      dryRun: nil,
      format: nil,
      headerTemplate: nil,
      emitExtensionStubs: nil,
      generateInit: nil,
      defaultDecodeFailurePolicy: nil
    )

    #expect(throws: ToolingFailure.self) {
      try validateToolingConfigTemplate(
        .init(schemaVersion: toolingSupportedSchemaVersion, generate: generate, validate: nil),
        against: model
      )
    }

    #expect(throws: ToolingFailure.self) {
      try validateResolvedToolingSchemaConfig(
        .init(generateTemplate: generate),
        against: model,
        context: "generate"
      )
    }
  }
}
