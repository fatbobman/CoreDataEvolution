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

/// Top-level inspectable model graph shared by `inspect` and future generate/validate engines.
///
/// Keep this type independent from `NSManagedObjectModel` so later layers can work from a stable,
/// serializable representation instead of Core Data runtime objects.
public struct ToolingModelIR: Codable, Sendable, Equatable {
  public let source: ToolingModelSourceIR
  public let generationPolicy: ToolingGenerationPolicyIR
  public let entities: [ToolingEntityIR]

  public init(
    source: ToolingModelSourceIR,
    generationPolicy: ToolingGenerationPolicyIR,
    entities: [ToolingEntityIR]
  ) {
    self.source = source
    self.generationPolicy = generationPolicy
    self.entities = entities
  }
}

/// Captures the concrete model input that produced the IR.
public struct ToolingModelSourceIR: Codable, Sendable, Equatable {
  public let originalPath: String
  public let selectedSourcePath: String
  public let compiledModelPath: String
  public let inputKind: ToolingModelInputKind
  public let selectedVersionName: String?

  public init(
    originalPath: String,
    selectedSourcePath: String,
    compiledModelPath: String,
    inputKind: ToolingModelInputKind,
    selectedVersionName: String?
  ) {
    self.originalPath = originalPath
    self.selectedSourcePath = selectedSourcePath
    self.compiledModelPath = compiledModelPath
    self.inputKind = inputKind
    self.selectedVersionName = selectedVersionName
  }
}

/// Resolved generation-facing policy values used when building the IR.
///
/// This is intentionally a subset of generate behavior. File writing and formatter execution still
/// belong to later engine layers.
public struct ToolingGenerationPolicyIR: Codable, Sendable, Equatable {
  public let accessLevel: ToolingAccessLevel
  public let singleFile: Bool
  public let splitByEntity: Bool
  public let generateInit: Bool
  public let relationshipSetterPolicy: ToolingRelationshipSetterPolicy
  public let relationshipCountPolicy: ToolingRelationshipCountPolicy
  public let defaultDecodeFailurePolicy: ToolingDecodeFailurePolicy

  public init(
    accessLevel: ToolingAccessLevel,
    singleFile: Bool,
    splitByEntity: Bool,
    generateInit: Bool,
    relationshipSetterPolicy: ToolingRelationshipSetterPolicy,
    relationshipCountPolicy: ToolingRelationshipCountPolicy,
    defaultDecodeFailurePolicy: ToolingDecodeFailurePolicy
  ) {
    self.accessLevel = accessLevel
    self.singleFile = singleFile
    self.splitByEntity = splitByEntity
    self.generateInit = generateInit
    self.relationshipSetterPolicy = relationshipSetterPolicy
    self.relationshipCountPolicy = relationshipCountPolicy
    self.defaultDecodeFailurePolicy = defaultDecodeFailurePolicy
  }
}

/// Entity-level IR used by inspect and later code generation.
///
/// Composition fields currently appear in two places on purpose:
/// - `attributes` still contains the original persistent field with `storage.method == .composition`
/// - `compositions` contains the higher-level composition view used by future generation
///
/// Generate/validate engines should treat `.composition` attributes as persistent backing fields
/// and avoid generating them like ordinary attributes a second time.
public struct ToolingEntityIR: Codable, Sendable, Equatable {
  public let name: String
  public let managedObjectClassName: String?
  public let representedClassName: String?
  public let attributes: [ToolingAttributeIR]
  public let relationships: [ToolingRelationshipIR]
  public let compositions: [ToolingCompositionIR]

  public init(
    name: String,
    managedObjectClassName: String?,
    representedClassName: String?,
    attributes: [ToolingAttributeIR],
    relationships: [ToolingRelationshipIR],
    compositions: [ToolingCompositionIR]
  ) {
    self.name = name
    self.managedObjectClassName = managedObjectClassName
    self.representedClassName = representedClassName
    self.attributes = attributes
    self.relationships = relationships
    self.compositions = compositions
  }
}

/// Attribute-level IR after applying `typeMappings`, `attributeRules`, and default policies.
///
/// Model defaults are preserved as pre-rendered Swift literals so generate can use the exact model
/// value without re-deriving it from the resolved Swift type.
public struct ToolingAttributeIR: Codable, Sendable, Equatable {
  public let persistentName: String
  public let swiftName: String
  public let coreDataAttributeType: String
  public let coreDataPrimitiveType: String?
  public let isUnique: Bool
  public let isTransient: Bool
  public let isOptional: Bool
  public let hasModelDefaultValue: Bool
  public let modelDefaultValueLiteral: String?
  public let storage: ToolingStorageIR

  public init(
    persistentName: String,
    swiftName: String,
    coreDataAttributeType: String,
    coreDataPrimitiveType: String?,
    isUnique: Bool = false,
    isTransient: Bool = false,
    isOptional: Bool,
    hasModelDefaultValue: Bool,
    modelDefaultValueLiteral: String?,
    storage: ToolingStorageIR
  ) {
    self.persistentName = persistentName
    self.swiftName = swiftName
    self.coreDataAttributeType = coreDataAttributeType
    self.coreDataPrimitiveType = coreDataPrimitiveType
    self.isUnique = isUnique
    self.isTransient = isTransient
    self.isOptional = isOptional
    self.hasModelDefaultValue = hasModelDefaultValue
    self.modelDefaultValueLiteral = modelDefaultValueLiteral
    self.storage = storage
  }
}

/// Resolved storage behavior for one attribute.
///
/// `swiftType` is best-effort for inspect. Future generate/validate engines may choose to reject
/// unresolved entries earlier, but inspect keeps them visible and reports diagnostics instead.
public struct ToolingStorageIR: Codable, Sendable, Equatable {
  public let method: ToolingAttributeStorageRule
  public let swiftType: String?
  public let nonOptionalSwiftType: String?
  public let transformerType: String?
  public let decodeFailurePolicy: ToolingDecodeFailurePolicy?
  public let isResolved: Bool

  public init(
    method: ToolingAttributeStorageRule,
    swiftType: String?,
    nonOptionalSwiftType: String?,
    transformerType: String?,
    decodeFailurePolicy: ToolingDecodeFailurePolicy?,
    isResolved: Bool
  ) {
    self.method = method
    self.swiftType = swiftType
    self.nonOptionalSwiftType = nonOptionalSwiftType
    self.transformerType = transformerType
    self.decodeFailurePolicy = decodeFailurePolicy
    self.isResolved = isResolved
  }
}

public enum ToolingRelationshipCardinalityIR: String, Codable, Sendable, Equatable {
  case toOne
  case toManyUnordered
  case toManyOrdered
}

/// Relationship IR keeps only structural data required by inspect and future helper generation.
public struct ToolingRelationshipIR: Codable, Sendable, Equatable {
  public let persistentName: String
  public let swiftName: String
  public let destinationEntityName: String?
  public let inverseRelationshipName: String?
  public let cardinality: ToolingRelationshipCardinalityIR
  public let isOptional: Bool
  public let minCount: Int
  public let maxCount: Int
  public let deleteRule: String

  public init(
    persistentName: String,
    swiftName: String,
    destinationEntityName: String?,
    inverseRelationshipName: String?,
    cardinality: ToolingRelationshipCardinalityIR,
    isOptional: Bool,
    minCount: Int,
    maxCount: Int,
    deleteRule: String
  ) {
    self.persistentName = persistentName
    self.swiftName = swiftName
    self.destinationEntityName = destinationEntityName
    self.inverseRelationshipName = inverseRelationshipName
    self.cardinality = cardinality
    self.isOptional = isOptional
    self.minCount = minCount
    self.maxCount = maxCount
    self.deleteRule = deleteRule
  }
}

/// Reserved IR for composition-aware tooling flows.
///
/// The current tooling pipeline already carries `compositionRules` into inspect/build IR, but it
/// still does not generate or parse standalone `@Composition` source declarations. Keeping one
/// shared IR shape here lets inspect, future generation, and future validation converge on the
/// same composition-field mapping model.
public struct ToolingCompositionIR: Codable, Sendable, Equatable {
  public let swiftName: String
  public let swiftType: String
  public let persistentFields: [String]
  public let fieldRules: [ToolingCompositionFieldIR]

  public init(
    swiftName: String,
    swiftType: String,
    persistentFields: [String],
    fieldRules: [ToolingCompositionFieldIR] = []
  ) {
    self.swiftName = swiftName
    self.swiftType = swiftType
    self.persistentFields = persistentFields
    self.fieldRules = fieldRules
  }
}

/// One composition leaf field mapping supplied by tooling configuration.
public struct ToolingCompositionFieldIR: Codable, Sendable, Equatable {
  public let persistentName: String
  public let swiftName: String

  public init(
    persistentName: String,
    swiftName: String
  ) {
    self.persistentName = persistentName
    self.swiftName = swiftName
  }
}
