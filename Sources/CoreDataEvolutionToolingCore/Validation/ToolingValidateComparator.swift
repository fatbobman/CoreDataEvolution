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

/// Compares model/config expectations against parsed developer source.
///
/// The comparator assumes macro expansion is correct and only validates the source inputs that feed
/// those macros.
public enum ToolingValidateComparator {
  public static func compareQuick(
    expected modelIR: ToolingModelIR,
    actual sourceIR: ToolingSourceModelIR,
    level: ToolingValidationLevel
  ) -> [ToolingDiagnostic] {
    var diagnostics: [ToolingDiagnostic] = []

    let sourceEntities = Dictionary(
      grouping: sourceIR.entities, by: { $0.objcEntityName ?? $0.className })
    let expectedEntityNames = Set(modelIR.entities.map(\.name))

    for (entityName, matches) in sourceEntities where matches.count > 1 {
      diagnostics.append(
        error(
          "validate found multiple @PersistentModel classes for entity '\(entityName)'."
        )
      )
    }

    for entity in modelIR.entities {
      guard let sourceEntity = sourceEntities[entity.name]?.first else {
        diagnostics.append(error("validate could not find source entity '\(entity.name)'."))
        continue
      }

      if sourceEntity.objcEntityName == nil && sourceEntity.className != entity.name {
        diagnostics.append(
          error(
            "validate requires source entity '\(sourceEntity.className)' to declare explicit @objc(\(entity.name))."
          )
        )
      }

      compareEntity(
        entity,
        sourceEntity: sourceEntity,
        generationPolicy: modelIR.generationPolicy,
        level: level,
        diagnostics: &diagnostics
      )
    }

    for sourceEntity in sourceIR.entities
    where expectedEntityNames.contains(sourceEntity.objcEntityName ?? sourceEntity.className)
      == false
    {
      diagnostics.append(
        error(
          "validate found extra @PersistentModel entity '\(sourceEntity.objcEntityName ?? sourceEntity.className)' not present in the model."
        )
      )
    }

    return diagnostics
  }

  private static func compareEntity(
    _ entity: ToolingEntityIR,
    sourceEntity: ToolingSourceEntityIR,
    generationPolicy: ToolingGenerationPolicyIR,
    level: ToolingValidationLevel,
    diagnostics: inout [ToolingDiagnostic]
  ) {
    comparePersistentModelArguments(
      entityName: entity.name,
      actual: sourceEntity.persistentModelArguments,
      expected: generationPolicy,
      diagnostics: &diagnostics
    )

    if sourceEntity.customMembers.isEmpty == false {
      let summary = sourceEntity.customMembers
        .map { "\($0.kind == .function ? "func" : "computed var") \($0.name)" }
        .sorted()
        .joined(separator: ", ")
      let modeText = level == .exact ? "exact" : "conformance"
      diagnostics.append(
        .init(
          severity: .note,
          code: nil,
          message:
            "validate \(modeText) found custom members inside '\(entity.name)': \(summary). Prefer hand-written extension files for methods and computed properties.",
          hint:
            "Use generate.emitExtensionStubs to create companion extension files, then move custom behavior there."
        )
      )
    }

    let sourceProperties = Dictionary(
      uniqueKeysWithValues: sourceEntity.properties.map { ($0.name, $0) })
    var expectedPropertyNames = Set<String>()
    let compositionPairs: [(String, ToolingCompositionIR)] = entity.compositions.compactMap {
      composition in
      guard let persistentField = composition.persistentFields.first else { return nil }
      return (persistentField, composition)
    }
    let compositionByPersistentName = Dictionary(uniqueKeysWithValues: compositionPairs)

    for attribute in entity.attributes {
      let expectedName: String
      let expectedType: String
      if attribute.storage.method == .composition,
        let composition = compositionByPersistentName[attribute.persistentName]
      {
        expectedName = composition.swiftName
        expectedType = attribute.isOptional ? "\(composition.swiftType)?" : composition.swiftType
      } else {
        expectedName = attribute.swiftName
        expectedType = attribute.storage.swiftType ?? "<unresolved>"
      }
      expectedPropertyNames.insert(expectedName)

      guard let sourceProperty = sourceProperties[expectedName] else {
        diagnostics.append(
          error("validate could not find property '\(entity.name).\(expectedName)'."))
        continue
      }

      compareAttribute(
        entityName: entity.name,
        attribute: attribute,
        expectedPropertyName: expectedName,
        expectedType: expectedType,
        sourceProperty: sourceProperty,
        diagnostics: &diagnostics
      )
    }

    for relationship in entity.relationships {
      expectedPropertyNames.insert(relationship.swiftName)
      guard let sourceProperty = sourceProperties[relationship.swiftName] else {
        diagnostics.append(
          error("validate could not find relationship '\(entity.name).\(relationship.swiftName)'."))
        continue
      }

      compareRelationship(
        entityName: entity.name,
        relationship: relationship,
        sourceProperty: sourceProperty,
        diagnostics: &diagnostics
      )
    }

    for sourceProperty in sourceEntity.properties
    where sourceProperty.isStored && sourceProperty.isStatic == false {
      guard expectedPropertyNames.contains(sourceProperty.name) == false else { continue }

      if sourceProperty.hasIgnore {
        continue
      }

      diagnostics.append(
        error(
          "validate found extra stored property '\(entity.name).\(sourceProperty.name)'. Mark it with @Ignore if it is model-external state."
        )
      )
    }
  }

  private static func comparePersistentModelArguments(
    entityName: String,
    actual: ToolingSourcePersistentModelArgumentsIR,
    expected: ToolingGenerationPolicyIR,
    diagnostics: inout [ToolingDiagnostic]
  ) {
    if actual.generateInit != expected.generateInit {
      diagnostics.append(
        error(
          "validate found generateInit mismatch for '\(entityName)'. Expected '\(expected.generateInit)', found '\(actual.generateInit)'."
        )
      )
    }

    if actual.relationshipSetterPolicy != expected.relationshipSetterPolicy {
      diagnostics.append(
        error(
          "validate found relationshipSetterPolicy mismatch for '\(entityName)'. Expected '\(expected.relationshipSetterPolicy.rawValue)', found '\(actual.relationshipSetterPolicy.rawValue)'."
        )
      )
    }

    if actual.relationshipCountPolicy != expected.relationshipCountPolicy {
      diagnostics.append(
        error(
          "validate found relationshipCountPolicy mismatch for '\(entityName)'. Expected '\(expected.relationshipCountPolicy.rawValue)', found '\(actual.relationshipCountPolicy.rawValue)'."
        )
      )
    }
  }

  private static func compareAttribute(
    entityName: String,
    attribute: ToolingAttributeIR,
    expectedPropertyName: String,
    expectedType: String,
    sourceProperty: ToolingSourcePropertyIR,
    diagnostics: inout [ToolingDiagnostic]
  ) {
    if sourceProperty.hasIgnore {
      diagnostics.append(
        error(
          "validate does not allow @Ignore to shadow persistent property '\(entityName).\(expectedPropertyName)'."
        )
      )
    }

    guard sourceProperty.isStored else {
      diagnostics.append(
        error("validate requires '\(entityName).\(expectedPropertyName)' to be a stored property."))
      return
    }

    if normalizeTypeName(sourceProperty.typeName) != normalizeTypeName(expectedType) {
      diagnostics.append(
        error(
          "validate found type mismatch for '\(entityName).\(expectedPropertyName)'. Expected '\(expectedType)', found '\(sourceProperty.typeName ?? "<missing>")'."
        )
      )
    }

    let expectedOriginalName =
      attribute.persistentName == expectedPropertyName ? nil : attribute.persistentName
    let actualOriginalName = sourceProperty.attribute?.originalName
    if expectedOriginalName != actualOriginalName {
      diagnostics.append(
        error(
          "validate found originalName mismatch for '\(entityName).\(expectedPropertyName)'. Expected '\(expectedOriginalName ?? "<none>")', found '\(actualOriginalName ?? "<none>")'."
        )
      )
    }

    let actualStorageMethod = sourceProperty.attribute?.storageMethod ?? .default
    if actualStorageMethod != attribute.storage.method {
      diagnostics.append(
        error(
          "validate found storageMethod mismatch for '\(entityName).\(expectedPropertyName)'. Expected '\(attribute.storage.method.rawValue)', found '\(actualStorageMethod.rawValue)'."
        )
      )
    }

    let actualUnique = sourceProperty.attribute?.isUnique ?? false
    if actualUnique != attribute.isUnique {
      diagnostics.append(
        error(
          "validate found unique mismatch for '\(entityName).\(expectedPropertyName)'. Expected '\(attribute.isUnique)', found '\(actualUnique)'."
        )
      )
    }

    let actualTransient = sourceProperty.attribute?.isTransient ?? false
    if actualTransient != attribute.isTransient {
      diagnostics.append(
        error(
          "validate found transient mismatch for '\(entityName).\(expectedPropertyName)'. Expected '\(attribute.isTransient)', found '\(actualTransient)'."
        )
      )
    }

    if attribute.storage.method == .transformed,
      sourceProperty.attribute?.transformerType != attribute.storage.transformerType
    {
      diagnostics.append(
        error(
          "validate found transformer mismatch for '\(entityName).\(expectedPropertyName)'. Expected '\(attribute.storage.transformerType ?? "<none>")', found '\(sourceProperty.attribute?.transformerType ?? "<none>")'."
        )
      )
    }

    if shouldCompareDecodeFailurePolicy(for: attribute.storage.method) {
      let expectedPolicy = attribute.storage.decodeFailurePolicy ?? .fallbackToDefaultValue
      let actualPolicy = sourceProperty.attribute?.decodeFailurePolicy ?? .fallbackToDefaultValue
      if actualPolicy != expectedPolicy {
        diagnostics.append(
          error(
            "validate found decodeFailurePolicy mismatch for '\(entityName).\(expectedPropertyName)'. Expected '\(expectedPolicy.rawValue)', found '\(actualPolicy.rawValue)'."
          )
        )
      }
    }

    if attribute.isOptional {
      if let actualDefault = sourceProperty.defaultValueLiteral,
        normalizeLiteral(actualDefault) != "nil"
      {
        diagnostics.append(
          error(
            "validate only allows optional persistent property '\(entityName).\(expectedPropertyName)' to omit a default or use nil."
          )
        )
      }
      return
    }

    switch attribute.storage.method {
    case .default:
      let expectedDefault = normalizeLiteral(attribute.modelDefaultValueLiteral)
      let actualDefault = normalizeLiteral(sourceProperty.defaultValueLiteral)
      if actualDefault != expectedDefault {
        diagnostics.append(
          error(
            "validate found default value mismatch for '\(entityName).\(expectedPropertyName)'. Expected '\(attribute.modelDefaultValueLiteral ?? "<missing>")', found '\(sourceProperty.defaultValueLiteral ?? "<missing>")'."
          )
        )
      }
    case .raw, .codable, .composition, .transformed:
      diagnostics.append(
        error(
          "validate does not support non-optional \(attribute.storage.method.rawValue) storage for '\(entityName).\(expectedPropertyName)'."
        )
      )
    }
  }

  private static func compareRelationship(
    entityName: String,
    relationship: ToolingRelationshipIR,
    sourceProperty: ToolingSourcePropertyIR,
    diagnostics: inout [ToolingDiagnostic]
  ) {
    if sourceProperty.hasIgnore {
      diagnostics.append(
        error(
          "validate does not allow @Ignore to shadow relationship '\(entityName).\(relationship.swiftName)'."
        )
      )
    }

    guard sourceProperty.isStored else {
      diagnostics.append(
        error(
          "validate requires relationship '\(entityName).\(relationship.swiftName)' to be a stored property."
        ))
      return
    }

    guard let relationshipShape = resolveRelationshipShape(sourceProperty) else {
      diagnostics.append(
        error(
          "validate could not recognize relationship shape for '\(entityName).\(relationship.swiftName)'."
        )
      )
      return
    }

    let expectedShape: ToolingSourceRelationshipShapeIR
    switch relationship.cardinality {
    case .toOne:
      expectedShape = .toOne
    case .toManyUnordered:
      expectedShape = .toManyUnordered
    case .toManyOrdered:
      expectedShape = .toManyOrdered
    }

    if relationshipShape != expectedShape {
      diagnostics.append(
        error(
          "validate found relationship cardinality mismatch for '\(entityName).\(relationship.swiftName)'. Expected '\(expectedShape.rawValue)', found '\(relationshipShape.rawValue)'."
        )
      )
    }

    let expectedType: String
    switch relationship.cardinality {
    case .toOne:
      expectedType = "\(relationship.destinationEntityName ?? "NSManagedObject")?"
    case .toManyUnordered:
      expectedType = "Set<\(relationship.destinationEntityName ?? "NSManagedObject")>"
    case .toManyOrdered:
      expectedType = "[\(relationship.destinationEntityName ?? "NSManagedObject")]"
    }

    if normalizeTypeName(sourceProperty.typeName) != normalizeTypeName(expectedType) {
      diagnostics.append(
        error(
          "validate found relationship type mismatch for '\(entityName).\(relationship.swiftName)'. Expected '\(expectedType)', found '\(sourceProperty.typeName ?? "<missing>")'."
        )
      )
    }
  }

  private static func shouldCompareDecodeFailurePolicy(
    for storageMethod: ToolingAttributeStorageRule
  ) -> Bool {
    switch storageMethod {
    case .raw, .codable, .transformed:
      return true
    case .default, .composition:
      return false
    }
  }

  private static func normalizeLiteral(_ literal: String?) -> String? {
    literal?.replacingOccurrences(of: " ", with: "")
  }

  private static func normalizeTypeName(_ typeName: String?) -> String? {
    typeName?.replacingOccurrences(of: " ", with: "")
  }

  private static func resolveRelationshipShape(
    _ property: ToolingSourcePropertyIR
  ) -> ToolingSourceRelationshipShapeIR? {
    if let relationshipShape = property.relationshipShape {
      return relationshipShape
    }

    guard let typeName = property.typeName else {
      return nil
    }
    let normalized = normalizeTypeName(typeName)
    if normalized?.hasPrefix("Set<") == true {
      return .toManyUnordered
    }
    if normalized?.hasPrefix("[") == true || normalized?.hasPrefix("Array<") == true {
      return .toManyOrdered
    }
    return .toOne
  }

  private static func error(_ message: String) -> ToolingDiagnostic {
    .init(severity: .error, code: .validationFailed, message: message)
  }
}
