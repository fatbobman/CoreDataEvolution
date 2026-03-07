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
import Testing

@testable import CoreDataEvolution

struct RuntimeSchemaTests {
  @Test("runtime schema collection returns entity schemas in input order")
  func entitySchemaCollectionPreservesInputOrder() {
    let schemas = CDRuntimeSchemaCollection.entitySchemas([
      ManualRuntimeSchemaTag.self,
      ManualRuntimeSchemaItem.self,
    ])

    #expect(schemas.map(\.entityName) == ["Tag", "Item"])
    #expect(schemas[1].attributes.first?.isUnique == true)
    #expect(
      schemas[1].uniquenessConstraints == [
        CDRuntimeUniquenessConstraint(persistentPropertyNames: ["title"])
      ])
  }

  @Test("runtime model builder reuses cached models for the same type list")
  func runtimeModelBuilderCachesEquivalentModels() throws {
    let first = try NSManagedObjectModel.makeRuntimeModel([
      ManualRuntimeSchemaTag.self,
      ManualRuntimeSchemaItem.self,
    ])
    let second = try NSManagedObjectModel.makeRuntimeModel([
      ManualRuntimeSchemaTag.self,
      ManualRuntimeSchemaItem.self,
    ])

    #expect(first === second)
  }

  @Test("runtime model builder preserves supported primitive defaults")
  func runtimeModelBuilderPreservesSupportedPrimitiveDefaults() throws {
    let model = try NSManagedObjectModel.makeRuntimeModel([ManualRuntimeSchemaDefaults.self])
    let entity = try #require(model.entitiesByName["RuntimeDefaults"])

    let createdAt = try #require(entity.attributesByName["createdAt"])
    #expect(createdAt.defaultValue as? Date == .distantPast)

    let payload = try #require(entity.attributesByName["payload"])
    #expect(payload.defaultValue as? Data == Data())

    let fileURL = try #require(entity.attributesByName["fileURL"])
    #expect(fileURL.defaultValue as? URL == URL(fileURLWithPath: "/tmp/runtime-schema"))
  }

  @Test("runtime model builder marks transient attributes")
  func runtimeModelBuilderMarksTransientAttributes() throws {
    let model = try NSManagedObjectModel.makeRuntimeModel([ManualRuntimeSchemaTransient.self])
    let entity = try #require(model.entitiesByName["RuntimeTransient"])
    let cachedSummary = try #require(entity.attributesByName["cachedSummary"])

    #expect(cachedSummary.isTransient)
    #expect(cachedSummary.attributeType == .stringAttributeType)
    #expect(cachedSummary.defaultValue == nil)
  }

  @Test("runtime model builder rejects unsupported primitive default expressions")
  func runtimeModelBuilderRejectsUnsupportedDefaultExpressions() throws {
    #expect(
      throws: CDRuntimeModelBuilderError.unsupportedDefaultValueExpression(
        entityName: "RuntimeInvalidDefaults",
        attributeName: "createdAt",
        expression: "Date()",
        primitiveType: .date
      )
    ) {
      _ = try NSManagedObjectModel.makeRuntimeModel([ManualRuntimeSchemaInvalidDefaults.self])
    }
  }

  @Test("runtime model builder requires declared inverse relationships to resolve")
  func runtimeModelBuilderRejectsMissingDeclaredInverse() throws {
    #expect(
      throws: CDRuntimeModelBuilderError.missingInverse(
        entityName: "RuntimeDocument",
        relationshipName: "owner",
        targetEntityName: "RuntimeUser"
      )
    ) {
      _ = try NSManagedObjectModel.makeRuntimeModel([
        ManualRuntimeSchemaDocument.self,
        ManualRuntimeSchemaUser.self,
      ])
    }
  }

  @Test("runtime model builder respects explicit relationship count overrides")
  func runtimeModelBuilderRespectsExplicitRelationshipCounts() throws {
    let model = try NSManagedObjectModel.makeRuntimeModel([
      ManualRuntimeSchemaCountBoundOwner.self,
      ManualRuntimeSchemaCountBoundDocument.self,
    ])

    let owner = try #require(model.entitiesByName["CountBoundOwner"])
    let documents = try #require(owner.relationshipsByName["documents"])
    #expect(documents.minCount == 1)
    #expect(documents.maxCount == 3)

    let document = try #require(model.entitiesByName["CountBoundDocument"])
    let ownerRef = try #require(document.relationshipsByName["owner"])
    #expect(ownerRef.minCount == 0)
    #expect(ownerRef.maxCount == 1)
  }
}

private final class ManualRuntimeSchemaItem: NSManagedObject, CDRuntimeSchemaProviding {
  static let __cdRuntimeEntitySchema = CDRuntimeEntitySchema(
    entityName: "Item",
    managedObjectClassName: NSStringFromClass(ManualRuntimeSchemaItem.self),
    attributes: [
      CDRuntimeAttributeSchema(
        swiftName: "title",
        persistentName: "title",
        swiftTypeName: "String",
        isOptional: false,
        defaultValueExpression: "\"\"",
        storage: .primitive(.string),
        isUnique: true
      )
    ],
    relationships: [
      CDRuntimeRelationshipSchema(
        swiftName: "tags",
        persistentName: "tags",
        targetTypeName: "ManualRuntimeSchemaTag",
        inverseName: "items",
        deleteRule: .nullify,
        kind: .toManySet,
        isOptional: true
      )
    ],
    uniquenessConstraints: [
      CDRuntimeUniquenessConstraint(persistentPropertyNames: ["title"])
    ]
  )
}

private final class ManualRuntimeSchemaTag: NSManagedObject, CDRuntimeSchemaProviding {
  static let __cdRuntimeEntitySchema = CDRuntimeEntitySchema(
    entityName: "Tag",
    managedObjectClassName: NSStringFromClass(ManualRuntimeSchemaTag.self),
    attributes: [],
    relationships: [
      CDRuntimeRelationshipSchema(
        swiftName: "items",
        persistentName: "items",
        targetTypeName: "ManualRuntimeSchemaItem",
        inverseName: "tags",
        deleteRule: .nullify,
        kind: .toManySet,
        isOptional: true
      )
    ]
  )
}

private final class ManualRuntimeSchemaDefaults: NSManagedObject, CDRuntimeSchemaProviding {
  static let __cdRuntimeEntitySchema = CDRuntimeEntitySchema(
    entityName: "RuntimeDefaults",
    managedObjectClassName: NSStringFromClass(ManualRuntimeSchemaDefaults.self),
    attributes: [
      CDRuntimeAttributeSchema(
        swiftName: "createdAt",
        persistentName: "createdAt",
        swiftTypeName: "Date",
        isOptional: false,
        defaultValueExpression: "Date.distantPast",
        storage: .primitive(.date)
      ),
      CDRuntimeAttributeSchema(
        swiftName: "payload",
        persistentName: "payload",
        swiftTypeName: "Data",
        isOptional: false,
        defaultValueExpression: "Data()",
        storage: .primitive(.data)
      ),
      CDRuntimeAttributeSchema(
        swiftName: "fileURL",
        persistentName: "fileURL",
        swiftTypeName: "URL",
        isOptional: false,
        defaultValueExpression: "URL(fileURLWithPath: \"/tmp/runtime-schema\")",
        storage: .primitive(.url)
      ),
    ],
    relationships: []
  )
}

private final class ManualRuntimeSchemaInvalidDefaults: NSManagedObject, CDRuntimeSchemaProviding {
  static let __cdRuntimeEntitySchema = CDRuntimeEntitySchema(
    entityName: "RuntimeInvalidDefaults",
    managedObjectClassName: NSStringFromClass(ManualRuntimeSchemaInvalidDefaults.self),
    attributes: [
      CDRuntimeAttributeSchema(
        swiftName: "createdAt",
        persistentName: "createdAt",
        swiftTypeName: "Date",
        isOptional: false,
        defaultValueExpression: "Date()",
        storage: .primitive(.date)
      )
    ],
    relationships: []
  )
}

private final class ManualRuntimeSchemaTransient: NSManagedObject, CDRuntimeSchemaProviding {
  static let __cdRuntimeEntitySchema = CDRuntimeEntitySchema(
    entityName: "RuntimeTransient",
    managedObjectClassName: NSStringFromClass(ManualRuntimeSchemaTransient.self),
    attributes: [
      CDRuntimeAttributeSchema(
        swiftName: "cachedSummary",
        persistentName: "cachedSummary",
        swiftTypeName: "String",
        isOptional: false,
        defaultValueExpression: "\"\"",
        storage: .primitive(.string),
        isTransient: true
      )
    ],
    relationships: []
  )
}

private final class ManualRuntimeSchemaDocument: NSManagedObject, CDRuntimeSchemaProviding {
  static let __cdRuntimeEntitySchema = CDRuntimeEntitySchema(
    entityName: "RuntimeDocument",
    managedObjectClassName: NSStringFromClass(ManualRuntimeSchemaDocument.self),
    attributes: [],
    relationships: [
      CDRuntimeRelationshipSchema(
        swiftName: "owner",
        persistentName: "owner",
        targetTypeName: "ManualRuntimeSchemaUser",
        inverseName: "owner",
        deleteRule: .nullify,
        kind: .toOne,
        isOptional: true
      )
    ]
  )
}

private final class ManualRuntimeSchemaUser: NSManagedObject, CDRuntimeSchemaProviding {
  static let __cdRuntimeEntitySchema = CDRuntimeEntitySchema(
    entityName: "RuntimeUser",
    managedObjectClassName: NSStringFromClass(ManualRuntimeSchemaUser.self),
    attributes: [],
    relationships: [
      CDRuntimeRelationshipSchema(
        swiftName: "documents",
        persistentName: "documents",
        targetTypeName: "ManualRuntimeSchemaDocument",
        inverseName: "owner",
        deleteRule: .nullify,
        kind: .toManySet,
        isOptional: true
      ),
      CDRuntimeRelationshipSchema(
        swiftName: "drafts",
        persistentName: "drafts",
        targetTypeName: "ManualRuntimeSchemaDocument",
        inverseName: "owner",
        deleteRule: .nullify,
        kind: .toManySet,
        isOptional: true
      ),
    ]
  )
}

private final class ManualRuntimeSchemaCountBoundOwner: NSManagedObject, CDRuntimeSchemaProviding {
  static let __cdRuntimeEntitySchema = CDRuntimeEntitySchema(
    entityName: "CountBoundOwner",
    managedObjectClassName: NSStringFromClass(ManualRuntimeSchemaCountBoundOwner.self),
    attributes: [],
    relationships: [
      CDRuntimeRelationshipSchema(
        swiftName: "documents",
        persistentName: "documents",
        targetTypeName: "ManualRuntimeSchemaCountBoundDocument",
        inverseName: "owner",
        deleteRule: .deny,
        minimumModelCount: 1,
        maximumModelCount: 3,
        kind: .toManySet,
        isOptional: true
      )
    ]
  )
}

private final class ManualRuntimeSchemaCountBoundDocument: NSManagedObject, CDRuntimeSchemaProviding
{
  static let __cdRuntimeEntitySchema = CDRuntimeEntitySchema(
    entityName: "CountBoundDocument",
    managedObjectClassName: NSStringFromClass(ManualRuntimeSchemaCountBoundDocument.self),
    attributes: [],
    relationships: [
      CDRuntimeRelationshipSchema(
        swiftName: "owner",
        persistentName: "owner",
        targetTypeName: "ManualRuntimeSchemaCountBoundOwner",
        inverseName: "documents",
        deleteRule: .nullify,
        kind: .toOne,
        isOptional: true
      )
    ]
  )
}
