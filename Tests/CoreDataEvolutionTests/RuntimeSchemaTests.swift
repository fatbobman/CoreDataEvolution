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
        kind: .toManySet,
        isOptional: true
      )
    ]
  )
}
