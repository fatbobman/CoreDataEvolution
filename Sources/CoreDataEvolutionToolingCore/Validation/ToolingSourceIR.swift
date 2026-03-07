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

/// Parsed source-side view consumed by `validate`.
///
/// This IR represents developer-authored source only. It intentionally does not model macro
/// expansion output such as `Keys`, `path`, or `__cdFieldTable`.
public struct ToolingSourceModelIR: Codable, Sendable, Equatable {
  public let sourceDirectory: String
  public let entities: [ToolingSourceEntityIR]

  public init(
    sourceDirectory: String,
    entities: [ToolingSourceEntityIR]
  ) {
    self.sourceDirectory = sourceDirectory
    self.entities = entities
  }
}

/// One parsed `@PersistentModel` class from developer-authored source.
public struct ToolingSourceEntityIR: Codable, Sendable, Equatable {
  public let filePath: String
  public let className: String
  public let objcEntityName: String?
  public let persistentModelArguments: ToolingSourcePersistentModelArgumentsIR
  public let properties: [ToolingSourcePropertyIR]
  public let customMembers: [ToolingSourceCustomMemberIR]

  public init(
    filePath: String,
    className: String,
    objcEntityName: String?,
    persistentModelArguments: ToolingSourcePersistentModelArgumentsIR,
    properties: [ToolingSourcePropertyIR],
    customMembers: [ToolingSourceCustomMemberIR]
  ) {
    self.filePath = filePath
    self.className = className
    self.objcEntityName = objcEntityName
    self.persistentModelArguments = persistentModelArguments
    self.properties = properties
    self.customMembers = customMembers
  }
}

/// Non-stored members declared inside the `@PersistentModel` class body.
///
/// Validate uses this to remind developers that exact mode expects custom behavior to live in
/// hand-written extension files rather than generated files.
public struct ToolingSourceCustomMemberIR: Codable, Sendable, Equatable {
  public let filePath: String
  public let name: String
  public let kind: ToolingSourceCustomMemberKind

  public init(
    filePath: String,
    name: String,
    kind: ToolingSourceCustomMemberKind
  ) {
    self.filePath = filePath
    self.name = name
    self.kind = kind
  }
}

public enum ToolingSourceCustomMemberKind: String, Codable, Sendable, Equatable {
  case function
  case computedProperty
}

/// Parsed `@PersistentModel(...)` arguments that affect generated source shape.
public struct ToolingSourcePersistentModelArgumentsIR: Codable, Sendable, Equatable {
  public let generateInit: Bool
  public let relationshipSetterPolicy: ToolingRelationshipSetterPolicy
  public let relationshipCountPolicy: ToolingRelationshipCountPolicy

  public init(
    generateInit: Bool,
    relationshipSetterPolicy: ToolingRelationshipSetterPolicy,
    relationshipCountPolicy: ToolingRelationshipCountPolicy
  ) {
    self.generateInit = generateInit
    self.relationshipSetterPolicy = relationshipSetterPolicy
    self.relationshipCountPolicy = relationshipCountPolicy
  }
}

/// One stored property declaration parsed from source.
///
/// `attribute` and `relationshipShape` remain lightweight because validate only needs enough
/// structure to compare source inputs against model-derived expectations.
public struct ToolingSourcePropertyIR: Codable, Sendable, Equatable {
  public let filePath: String
  public let name: String
  public let typeName: String?
  public let nonOptionalTypeName: String?
  public let declarationRange: ToolingTextRange
  public let declarationIndent: String
  public let isOptional: Bool
  public let defaultValueLiteral: String?
  public let defaultValueRange: ToolingTextRange?
  public let isStored: Bool
  public let isStatic: Bool
  public let hasIgnore: Bool
  public let attribute: ToolingSourceAttributeAnnotationIR?
  public let relationship: ToolingSourceRelationshipAnnotationIR?
  public let relationshipShape: ToolingSourceRelationshipShapeIR?

  public init(
    filePath: String,
    name: String,
    typeName: String?,
    nonOptionalTypeName: String?,
    declarationRange: ToolingTextRange,
    declarationIndent: String,
    isOptional: Bool,
    defaultValueLiteral: String?,
    defaultValueRange: ToolingTextRange?,
    isStored: Bool,
    isStatic: Bool,
    hasIgnore: Bool,
    attribute: ToolingSourceAttributeAnnotationIR?,
    relationship: ToolingSourceRelationshipAnnotationIR? = nil,
    relationshipShape: ToolingSourceRelationshipShapeIR?
  ) {
    self.filePath = filePath
    self.name = name
    self.typeName = typeName
    self.nonOptionalTypeName = nonOptionalTypeName
    self.declarationRange = declarationRange
    self.declarationIndent = declarationIndent
    self.isOptional = isOptional
    self.defaultValueLiteral = defaultValueLiteral
    self.defaultValueRange = defaultValueRange
    self.isStored = isStored
    self.isStatic = isStatic
    self.hasIgnore = hasIgnore
    self.attribute = attribute
    self.relationship = relationship
    self.relationshipShape = relationshipShape
  }
}

/// Parsed `@Attribute(...)` arguments from source.
public struct ToolingSourceAttributeAnnotationIR: Codable, Sendable, Equatable {
  public let range: ToolingTextRange
  public let isUnique: Bool
  public let isTransient: Bool
  public let persistentName: String?
  public let storageMethod: ToolingAttributeStorageRule?
  public let transformerType: String?
  public let decodeFailurePolicy: ToolingDecodeFailurePolicy?

  public init(
    range: ToolingTextRange,
    isUnique: Bool = false,
    isTransient: Bool = false,
    persistentName: String?,
    storageMethod: ToolingAttributeStorageRule?,
    transformerType: String?,
    decodeFailurePolicy: ToolingDecodeFailurePolicy?
  ) {
    self.range = range
    self.isUnique = isUnique
    self.isTransient = isTransient
    self.persistentName = persistentName
    self.storageMethod = storageMethod
    self.transformerType = transformerType
    self.decodeFailurePolicy = decodeFailurePolicy
  }
}

/// Parsed `@Relationship(...)` metadata from source.
public struct ToolingSourceRelationshipAnnotationIR: Codable, Sendable, Equatable {
  public let range: ToolingTextRange
  public let inversePropertyName: String
  public let deleteRule: String
  public let minimumModelCount: Int?
  public let maximumModelCount: Int?

  public init(
    range: ToolingTextRange,
    inversePropertyName: String,
    deleteRule: String,
    minimumModelCount: Int? = nil,
    maximumModelCount: Int? = nil
  ) {
    self.range = range
    self.inversePropertyName = inversePropertyName
    self.deleteRule = deleteRule
    self.minimumModelCount = minimumModelCount
    self.maximumModelCount = maximumModelCount
  }
}

/// Relationship cardinality recognized from the declared Swift type.
public enum ToolingSourceRelationshipShapeIR: String, Codable, Sendable, Equatable {
  case toOne
  case toManyUnordered
  case toManyOrdered
}
