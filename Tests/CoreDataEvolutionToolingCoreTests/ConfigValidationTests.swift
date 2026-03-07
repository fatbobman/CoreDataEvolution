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

  @Test("generate rejects Undefined attribute type")
  func generateRejectsUndefinedAttributeType() throws {
    let model = makeModelWithUndefinedAttribute()
    let template = makeGenerateValidationTemplate()

    try expectConfigFailure(template, code: .configInvalid) {
      try validateToolingConfigTemplate(template, against: model)
    }
  }

  @Test("generate rejects non-optional attribute without model default")
  func generateRejectsNonOptionalAttributeWithoutDefault() throws {
    let model = makeModelWithMissingNonOptionalDefault()
    let template = makeGenerateValidationTemplate()

    try expectConfigFailure(template, code: .configInvalid) {
      try validateToolingConfigTemplate(template, against: model)
    }
  }

  @Test("generate rejects non-optional custom storage even with model default")
  func generateRejectsNonOptionalCustomStorage() throws {
    let model = makeModelWithCustomStorageCandidate()
    let template = makeGenerateValidationTemplate(
      attributeRules: .init(
        entities: [
          "Item": [
            "status_raw": .init(
              swiftType: "ItemStatus",
              storageMethod: .raw
            )
          ]
        ]
      )
    )

    try expectConfigFailure(template, code: .configInvalid) {
      try validateToolingConfigTemplate(template, against: model)
    }
  }

  @Test("generate rejects transient attribute with custom storage")
  func generateRejectsTransientAttributeWithCustomStorage() throws {
    let model = makeModelWithTransientAttribute()
    let template = makeGenerateValidationTemplate(
      attributeRules: .init(
        entities: [
          "Item": [
            "scratch": .init(
              swiftType: "ItemScratch",
              storageMethod: .codable
            )
          ]
        ]
      )
    )

    try expectConfigFailure(template, code: .configInvalid) {
      try validateToolingConfigTemplate(template, against: model)
    }
  }

  @Test("generate rejects non-optional relationship")
  func generateRejectsNonOptionalRelationship() throws {
    let model = makeModelWithNonOptionalRelationship()
    let template = makeGenerateValidationTemplate()

    try expectConfigFailure(template, code: .configInvalid) {
      try validateToolingConfigTemplate(template, against: model)
    }
  }

  @Test("tooling rejects derived attributes in the model surface")
  func toolingRejectsDerivedAttributes() throws {
    let model = makeModelWithDerivedAttribute()
    let template = makeGenerateValidationTemplate()

    try expectConfigFailure(template, code: .configInvalid) {
      try validateToolingConfigTemplate(template, against: model)
    }
  }

  @Test("generate rejects relationship without inverse")
  func generateRejectsRelationshipWithoutInverse() throws {
    let model = makeModelWithRelationshipWithoutInverse()
    let template = makeGenerateValidationTemplate()

    try expectConfigFailure(template, code: .configInvalid) {
      try validateToolingConfigTemplate(template, against: model)
    }
  }

  @Test("tooling rejects no action delete rule in the model surface")
  func toolingRejectsNoActionDeleteRule() throws {
    let model = makeModelWithNoActionDeleteRule()
    let template = makeGenerateValidationTemplate()

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

  private func makeGenerateValidationTemplate(
    attributeRules: ToolingAttributeRules? = nil
  ) -> ToolingConfigTemplate {
    ToolingConfigTemplate(
      schemaVersion: toolingSupportedSchemaVersion,
      generate: .init(
        modelPath: "Models/AppModel.xcdatamodeld",
        modelVersion: nil,
        momcBin: nil,
        outputDir: "Generated/CoreDataEvolution",
        moduleName: "AppModels",
        typeMappings: nil,
        attributeRules: attributeRules,
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

  private func makeModelWithUndefinedAttribute() -> NSManagedObjectModel {
    let attribute = NSAttributeDescription()
    attribute.name = "mystery"
    attribute.attributeType = .undefinedAttributeType
    attribute.isOptional = true

    let entity = NSEntityDescription()
    entity.name = "Item"
    entity.managedObjectClassName = "NSManagedObject"
    entity.properties = [attribute]

    let model = NSManagedObjectModel()
    model.entities = [entity]
    return model
  }

  private func makeModelWithMissingNonOptionalDefault() -> NSManagedObjectModel {
    let attribute = NSAttributeDescription()
    attribute.name = "name"
    attribute.attributeType = .stringAttributeType
    attribute.isOptional = false

    let entity = NSEntityDescription()
    entity.name = "Item"
    entity.managedObjectClassName = "NSManagedObject"
    entity.properties = [attribute]

    let model = NSManagedObjectModel()
    model.entities = [entity]
    return model
  }

  private func makeModelWithCustomStorageCandidate() -> NSManagedObjectModel {
    let attribute = NSAttributeDescription()
    attribute.name = "status_raw"
    attribute.attributeType = .stringAttributeType
    attribute.isOptional = false
    attribute.defaultValue = "draft"

    let entity = NSEntityDescription()
    entity.name = "Item"
    entity.managedObjectClassName = "NSManagedObject"
    entity.properties = [attribute]

    let model = NSManagedObjectModel()
    model.entities = [entity]
    return model
  }

  private func makeModelWithNonOptionalRelationship() -> NSManagedObjectModel {
    let item = NSEntityDescription()
    item.name = "Item"
    item.managedObjectClassName = "NSManagedObject"

    let owner = NSEntityDescription()
    owner.name = "Owner"
    owner.managedObjectClassName = "NSManagedObject"

    let ownerRelationship = NSRelationshipDescription()
    ownerRelationship.name = "owner"
    ownerRelationship.destinationEntity = owner
    ownerRelationship.minCount = 1
    ownerRelationship.maxCount = 1
    ownerRelationship.isOptional = false

    let itemsRelationship = NSRelationshipDescription()
    itemsRelationship.name = "items"
    itemsRelationship.destinationEntity = item
    itemsRelationship.minCount = 0
    itemsRelationship.maxCount = 0
    itemsRelationship.isOptional = true

    ownerRelationship.inverseRelationship = itemsRelationship
    itemsRelationship.inverseRelationship = ownerRelationship

    item.properties = [ownerRelationship]
    owner.properties = [itemsRelationship]

    let model = NSManagedObjectModel()
    model.entities = [item, owner]
    return model
  }

  private func makeModelWithTransientAttribute() -> NSManagedObjectModel {
    let attribute = NSAttributeDescription()
    attribute.name = "scratch"
    attribute.attributeType = .stringAttributeType
    attribute.isOptional = true
    attribute.isTransient = true

    let entity = NSEntityDescription()
    entity.name = "Item"
    entity.managedObjectClassName = "NSManagedObject"
    entity.properties = [attribute]

    let model = NSManagedObjectModel()
    model.entities = [entity]
    return model
  }

  private func makeModelWithDerivedAttribute() -> NSManagedObjectModel {
    let attribute = NSDerivedAttributeDescription()
    attribute.name = "derivedName"
    attribute.attributeType = .stringAttributeType
    attribute.derivationExpression = NSExpression(forConstantValue: "derived")

    let entity = NSEntityDescription()
    entity.name = "Item"
    entity.managedObjectClassName = "NSManagedObject"
    entity.properties = [attribute]

    let model = NSManagedObjectModel()
    model.entities = [entity]
    return model
  }

  private func makeModelWithRelationshipWithoutInverse() -> NSManagedObjectModel {
    let item = NSEntityDescription()
    item.name = "Item"
    item.managedObjectClassName = "NSManagedObject"

    let owner = NSEntityDescription()
    owner.name = "Owner"
    owner.managedObjectClassName = "NSManagedObject"

    let ownerRelationship = NSRelationshipDescription()
    ownerRelationship.name = "owner"
    ownerRelationship.destinationEntity = owner
    ownerRelationship.minCount = 0
    ownerRelationship.maxCount = 1
    ownerRelationship.isOptional = true

    item.properties = [ownerRelationship]
    owner.properties = []

    let model = NSManagedObjectModel()
    model.entities = [item, owner]
    return model
  }

  private func makeModelWithNoActionDeleteRule() -> NSManagedObjectModel {
    let item = NSEntityDescription()
    item.name = "Item"
    item.managedObjectClassName = "NSManagedObject"

    let owner = NSEntityDescription()
    owner.name = "Owner"
    owner.managedObjectClassName = "NSManagedObject"

    let ownerRelationship = NSRelationshipDescription()
    ownerRelationship.name = "owner"
    ownerRelationship.destinationEntity = owner
    ownerRelationship.minCount = 0
    ownerRelationship.maxCount = 1
    ownerRelationship.isOptional = true
    ownerRelationship.deleteRule = .noActionDeleteRule

    let itemsRelationship = NSRelationshipDescription()
    itemsRelationship.name = "items"
    itemsRelationship.destinationEntity = item
    itemsRelationship.minCount = 0
    itemsRelationship.maxCount = 0
    itemsRelationship.isOptional = true
    itemsRelationship.deleteRule = .nullifyDeleteRule

    ownerRelationship.inverseRelationship = itemsRelationship
    itemsRelationship.inverseRelationship = ownerRelationship

    item.properties = [ownerRelationship]
    owner.properties = [itemsRelationship]

    let model = NSManagedObjectModel()
    model.entities = [item, owner]
    return model
  }
}
