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

import Foundation

/// Core Data primitive value kinds that can be expressed without custom transformation logic.
/// `Int` is intentionally represented as `.int64` at the schema layer so the runtime builder can
/// map from Swift ergonomics to stable Core Data storage types later.
public enum CDRuntimePrimitiveAttributeType: String, CaseIterable, Codable, Sendable {
  case string
  case bool
  case int16
  case int32
  case int64
  case float
  case double
  case decimal
  case date
  case data
  case uuid
  case url
}

/// Runtime storage description emitted by macros for test/debug model construction.
/// This keeps the metadata independent from `NSAttributeDescription` so the builder can stay as a
/// thin translation layer.
public enum CDRuntimeAttributeStorage: Sendable, Equatable {
  case primitive(CDRuntimePrimitiveAttributeType)
  case raw(backingTypeName: String)
  case codable
  case transformed(transformerTypeName: String)
  case composition(fields: [CDRuntimeCompositionFieldSchema])
}

/// One flattened field inside a composition-backed Core Data attribute.
public struct CDRuntimeCompositionFieldSchema: Sendable, Equatable {
  public let persistentName: String
  public let swiftTypeName: String
  public let primitiveType: CDRuntimePrimitiveAttributeType
  public let isOptional: Bool
  public let defaultValueExpression: String?

  public init(
    persistentName: String,
    swiftTypeName: String,
    primitiveType: CDRuntimePrimitiveAttributeType,
    isOptional: Bool,
    defaultValueExpression: String?
  ) {
    self.persistentName = persistentName
    self.swiftTypeName = swiftTypeName
    self.primitiveType = primitiveType
    self.isOptional = isOptional
    self.defaultValueExpression = defaultValueExpression
  }
}

/// Composition-level runtime metadata emitted by `@Composition`.
public protocol CDRuntimeCompositionSchemaProviding {
  static var __cdRuntimeCompositionFields: [CDRuntimeCompositionFieldSchema] { get }
}

/// Persistent attribute metadata consumed by the future runtime-model builder.
/// `defaultValueExpression` intentionally keeps the source literal shape for now so macro output can
/// stay simple while the builder design is still being finalized.
public struct CDRuntimeAttributeSchema: Sendable, Equatable {
  public let swiftName: String
  public let persistentName: String
  public let swiftTypeName: String
  public let isOptional: Bool
  public let defaultValueExpression: String?
  public let storage: CDRuntimeAttributeStorage
  public let isUnique: Bool

  public init(
    swiftName: String,
    persistentName: String,
    swiftTypeName: String,
    isOptional: Bool,
    defaultValueExpression: String?,
    storage: CDRuntimeAttributeStorage,
    isUnique: Bool = false
  ) {
    self.swiftName = swiftName
    self.persistentName = persistentName
    self.swiftTypeName = swiftTypeName
    self.isOptional = isOptional
    self.defaultValueExpression = defaultValueExpression
    self.storage = storage
    self.isUnique = isUnique
  }
}

public enum CDRuntimeRelationshipKind: String, Codable, Sendable {
  case toOne
  case toManySet
  case toManyArray
}

/// Relationship metadata available from source declarations alone.
/// Delete rules are intentionally not part of the first runtime-schema pass because current macros
/// do not model them; test/debug builders will apply a stable default later.
///
/// When `inverseName` is `nil`, the runtime builder falls back to inverse inference. That keeps
/// macro-emitted schema lightweight, but it also means runtime-only modeling currently requires a
/// single unambiguous inverse relationship per source/target entity pair.
public struct CDRuntimeRelationshipSchema: Sendable, Equatable {
  public let swiftName: String
  public let persistentName: String
  public let targetTypeName: String
  public let inverseName: String?
  public let kind: CDRuntimeRelationshipKind
  public let isOptional: Bool

  public init(
    swiftName: String,
    persistentName: String,
    targetTypeName: String,
    inverseName: String? = nil,
    kind: CDRuntimeRelationshipKind,
    isOptional: Bool
  ) {
    self.swiftName = swiftName
    self.persistentName = persistentName
    self.targetTypeName = targetTypeName
    self.inverseName = inverseName
    self.kind = kind
    self.isOptional = isOptional
  }
}

/// Future-proof entity-level uniqueness metadata. The first runtime-schema milestone only emits
/// single-field constraints from `@Attribute(.unique)`, but the shape is already compatible with
/// multi-field constraints when the design expands.
public struct CDRuntimeUniquenessConstraint: Sendable, Equatable {
  public let persistentPropertyNames: [String]

  public init(persistentPropertyNames: [String]) {
    self.persistentPropertyNames = persistentPropertyNames
  }
}

/// Full schema for one `@PersistentModel` type.
public struct CDRuntimeEntitySchema: Sendable, Equatable {
  public let entityName: String
  public let managedObjectClassName: String
  public let attributes: [CDRuntimeAttributeSchema]
  public let relationships: [CDRuntimeRelationshipSchema]
  public let uniquenessConstraints: [CDRuntimeUniquenessConstraint]

  public init(
    entityName: String,
    managedObjectClassName: String,
    attributes: [CDRuntimeAttributeSchema],
    relationships: [CDRuntimeRelationshipSchema],
    uniquenessConstraints: [CDRuntimeUniquenessConstraint] = []
  ) {
    self.entityName = entityName
    self.managedObjectClassName = managedObjectClassName
    self.attributes = attributes
    self.relationships = relationships
    self.uniquenessConstraints = uniquenessConstraints
  }
}
