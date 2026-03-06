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

@preconcurrency import CoreData
import CoreDataEvolutionToolingCore
import Foundation
import Testing

@Suite("Tooling Core Config Validation Tests")
struct ConfigValidationTests {
  @Test("generate rejects conflicting single file and split by entity options")
  func generateRejectsConflictingLayoutOptions() throws {
    let template = ToolingConfigTemplate(
      schemaVersion: toolingSupportedSchemaVersion,
      generate: .init(
        modelPath: "Models/AppModel.xcdatamodeld",
        modelVersion: nil,
        momcBin: nil,
        outputDir: "Generated/CoreDataEvolution",
        moduleName: "AppModels",
        typeMappings: nil,
        attributeRules: nil,
        accessLevel: .internal,
        singleFile: true,
        splitByEntity: true,
        overwrite: ToolingOverwriteMode.none,
        cleanStale: false,
        dryRun: false,
        format: ToolingFormatMode.none,
        headerTemplate: nil,
        generateInit: false,
        relationshipSetterPolicy: .warning,
        relationshipCountPolicy: ToolingRelationshipCountPolicy.none,
        defaultDecodeFailurePolicy: .fallbackToDefaultValue
      ),
      validate: nil
    )

    try expectConfigFailure(template, code: .configInvalid) {
      try validateToolingConfigTemplate(template)
    }
  }

  @Test("transformed storage requires transformer type")
  func transformedStorageRequiresTransformerType() throws {
    let template = ToolingConfigTemplate(
      schemaVersion: toolingSupportedSchemaVersion,
      generate: .init(
        modelPath: "Models/AppModel.xcdatamodeld",
        modelVersion: nil,
        momcBin: nil,
        outputDir: "Generated/CoreDataEvolution",
        moduleName: "AppModels",
        typeMappings: nil,
        attributeRules: .init(
          entities: [
            "Item": [
              "blob": .init(
                swiftType: "Payload",
                storageMethod: .transformed
              )
            ]
          ]
        ),
        accessLevel: .internal,
        singleFile: false,
        splitByEntity: true,
        overwrite: ToolingOverwriteMode.none,
        cleanStale: false,
        dryRun: false,
        format: ToolingFormatMode.none,
        headerTemplate: nil,
        generateInit: false,
        relationshipSetterPolicy: .warning,
        relationshipCountPolicy: ToolingRelationshipCountPolicy.none,
        defaultDecodeFailurePolicy: .fallbackToDefaultValue
      ),
      validate: nil
    )

    try expectConfigFailure(template, code: .configInvalid) {
      try validateToolingConfigTemplate(template)
    }
  }

  @Test("decode failure policy is rejected for default storage")
  func decodeFailurePolicyOnDefaultStorageIsRejected() throws {
    let template = ToolingConfigTemplate(
      schemaVersion: toolingSupportedSchemaVersion,
      generate: .init(
        modelPath: "Models/AppModel.xcdatamodeld",
        modelVersion: nil,
        momcBin: nil,
        outputDir: "Generated/CoreDataEvolution",
        moduleName: "AppModels",
        typeMappings: nil,
        attributeRules: .init(
          entities: [
            "Item": [
              "name": .init(
                decodeFailurePolicy: .debugAssertNil
              )
            ]
          ]
        ),
        accessLevel: .internal,
        singleFile: false,
        splitByEntity: true,
        overwrite: ToolingOverwriteMode.none,
        cleanStale: false,
        dryRun: false,
        format: ToolingFormatMode.none,
        headerTemplate: nil,
        generateInit: false,
        relationshipSetterPolicy: .warning,
        relationshipCountPolicy: ToolingRelationshipCountPolicy.none,
        defaultDecodeFailurePolicy: .fallbackToDefaultValue
      ),
      validate: nil
    )

    try expectConfigFailure(template, code: .configInvalid) {
      try validateToolingConfigTemplate(template)
    }
  }

  @Test("type mappings reject unknown Core Data primitive keys")
  func unknownPrimitiveTypeMappingKeyIsRejected() throws {
    let template = ToolingConfigTemplate(
      schemaVersion: toolingSupportedSchemaVersion,
      generate: .init(
        modelPath: "Models/AppModel.xcdatamodeld",
        modelVersion: nil,
        momcBin: nil,
        outputDir: "Generated/CoreDataEvolution",
        moduleName: "AppModels",
        typeMappings: .init(
          coreDataTypes: [
            "Unknown Primitive": .init(swiftType: "String")
          ]
        ),
        attributeRules: nil,
        accessLevel: .internal,
        singleFile: false,
        splitByEntity: true,
        overwrite: ToolingOverwriteMode.none,
        cleanStale: false,
        dryRun: false,
        format: ToolingFormatMode.none,
        headerTemplate: nil,
        generateInit: false,
        relationshipSetterPolicy: .warning,
        relationshipCountPolicy: ToolingRelationshipCountPolicy.none,
        defaultDecodeFailurePolicy: .fallbackToDefaultValue
      ),
      validate: nil
    )

    try expectConfigFailure(template, code: .configInvalid) {
      try validateToolingConfigTemplate(template)
    }
  }

  @Test("attribute rules reject missing model entities and fields")
  func missingEntityAndFieldAreRejectedAgainstModel() throws {
    let model = makeModel()
    let template = ToolingConfigTemplate(
      schemaVersion: toolingSupportedSchemaVersion,
      generate: .init(
        modelPath: "Models/AppModel.xcdatamodeld",
        modelVersion: nil,
        momcBin: nil,
        outputDir: "Generated/CoreDataEvolution",
        moduleName: "AppModels",
        typeMappings: nil,
        attributeRules: .init(
          entities: [
            "Ghost": [
              "name": .init(swiftName: "title")
            ]
          ]
        ),
        accessLevel: .internal,
        singleFile: false,
        splitByEntity: true,
        overwrite: ToolingOverwriteMode.none,
        cleanStale: false,
        dryRun: false,
        format: ToolingFormatMode.none,
        headerTemplate: nil,
        generateInit: false,
        relationshipSetterPolicy: .warning,
        relationshipCountPolicy: ToolingRelationshipCountPolicy.none,
        defaultDecodeFailurePolicy: .fallbackToDefaultValue
      ),
      validate: nil
    )

    try expectConfigFailure(template, code: .configInvalid) {
      try validateToolingConfigTemplate(template, against: model)
    }

    let fieldTemplate = ToolingConfigTemplate(
      schemaVersion: toolingSupportedSchemaVersion,
      generate: .init(
        modelPath: "Models/AppModel.xcdatamodeld",
        modelVersion: nil,
        momcBin: nil,
        outputDir: "Generated/CoreDataEvolution",
        moduleName: "AppModels",
        typeMappings: nil,
        attributeRules: .init(
          entities: [
            "Item": [
              "missingField": .init(swiftName: "title")
            ]
          ]
        ),
        accessLevel: .internal,
        singleFile: false,
        splitByEntity: true,
        overwrite: ToolingOverwriteMode.none,
        cleanStale: false,
        dryRun: false,
        format: ToolingFormatMode.none,
        headerTemplate: nil,
        generateInit: false,
        relationshipSetterPolicy: .warning,
        relationshipCountPolicy: ToolingRelationshipCountPolicy.none,
        defaultDecodeFailurePolicy: .fallbackToDefaultValue
      ),
      validate: nil
    )

    try expectConfigFailure(fieldTemplate, code: .configInvalid) {
      try validateToolingConfigTemplate(fieldTemplate, against: model)
    }
  }

  @Test("default storage requires an inferable Core Data primitive type")
  func defaultStorageRequiresInferablePrimitiveType() throws {
    let model = makeModel()
    let template = ToolingConfigTemplate(
      schemaVersion: toolingSupportedSchemaVersion,
      generate: .init(
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
        headerTemplate: nil,
        generateInit: false,
        relationshipSetterPolicy: .warning,
        relationshipCountPolicy: ToolingRelationshipCountPolicy.none,
        defaultDecodeFailurePolicy: .fallbackToDefaultValue
      ),
      validate: nil
    )

    try expectConfigFailure(template, code: .configInvalid) {
      try validateToolingConfigTemplate(template, against: model)
    }
  }

  private func expectConfigFailure(
    _ template: ToolingConfigTemplate,
    code: ToolingErrorCode,
    operation: () throws -> Void
  ) throws {
    do {
      try operation()
      Issue.record("Expected config validation to fail for template: \(template)")
    } catch let error as ToolingFailure {
      #expect(error.code == code)
      #expect(error.exitCode == 1)
    }
  }

  private func makeModel() -> NSManagedObjectModel {
    let nameAttribute = NSAttributeDescription()
    nameAttribute.name = "name"
    nameAttribute.attributeType = .stringAttributeType

    let countAttribute = NSAttributeDescription()
    countAttribute.name = "count"
    countAttribute.attributeType = .integer64AttributeType

    let entity = NSEntityDescription()
    entity.name = "Item"
    entity.managedObjectClassName = "NSManagedObject"
    let payloadAttribute = NSAttributeDescription()
    payloadAttribute.name = "payload"
    payloadAttribute.attributeType = .transformableAttributeType

    entity.properties = [nameAttribute, countAttribute, payloadAttribute]

    let model = NSManagedObjectModel()
    model.entities = [entity]
    return model
  }
}
