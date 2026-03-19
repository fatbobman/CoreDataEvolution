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
    level: ToolingValidationLevel,
    attributeRules: ToolingAttributeRules = .init()
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
        sourceIR: sourceIR,
        generationPolicy: modelIR.generationPolicy,
        level: level,
        attributeRules: attributeRules,
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
    sourceIR: ToolingSourceModelIR,
    generationPolicy: ToolingGenerationPolicyIR,
    level: ToolingValidationLevel,
    attributeRules: ToolingAttributeRules,
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
    let sourceRelationshipsByPersistentName = Dictionary(
      grouping: sourceEntity.properties.compactMap {
        property -> (String, ToolingSourcePropertyIR)? in
        guard property.relationshipShape != nil, property.isStored, property.isStatic == false
        else {
          return nil
        }
        let persistentName = property.relationship?.persistentName ?? property.name
        return (persistentName, property)
      },
      by: \.0
    ).mapValues { $0.map(\.1) }
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
      let expectedNonOptionalType: String
      if attribute.storage.method == .composition,
        let composition = compositionByPersistentName[attribute.persistentName]
      {
        expectedName = composition.swiftName
        expectedType = attribute.isOptional ? "\(composition.swiftType)?" : composition.swiftType
        expectedNonOptionalType = composition.swiftType
      } else {
        expectedName = attribute.swiftName
        expectedType = attribute.storage.swiftType ?? "<unresolved>"
        expectedNonOptionalType = attribute.storage.nonOptionalSwiftType ?? expectedType
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
        expectedNonOptionalType: expectedNonOptionalType,
        rule: attributeRules[entity: entity.name][attribute.persistentName] ?? .init(),
        sourceProperty: sourceProperty,
        sourceIR: sourceIR,
        diagnostics: &diagnostics
      )
    }

    for relationship in entity.relationships {
      let matches = sourceRelationshipsByPersistentName[relationship.persistentName] ?? []
      if matches.count > 1 {
        diagnostics.append(
          error(
            "validate found multiple source relationships mapping to persistent relationship '\(entity.name).\(relationship.persistentName)'."
          )
        )
        continue
      }
      guard let sourceProperty = matches.first else {
        diagnostics.append(
          error(
            "validate could not find relationship '\(entity.name).\(relationship.persistentName)'.")
        )
        continue
      }
      expectedPropertyNames.insert(sourceProperty.name)
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
  }

  private static func compareAttribute(
    entityName: String,
    attribute: ToolingAttributeIR,
    expectedPropertyName: String,
    expectedType: String,
    expectedNonOptionalType: String,
    rule: ToolingAttributeRule,
    sourceProperty: ToolingSourcePropertyIR,
    sourceIR: ToolingSourceModelIR,
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

    let shouldIgnoreOptionalityMismatch =
      rule.ignoreOptionality == true
      && attribute.isOptional
      && sourceProperty.isOptional == false
    let actualTypeName =
      shouldIgnoreOptionalityMismatch
      ? sourceProperty.nonOptionalTypeName ?? sourceProperty.typeName
      : sourceProperty.typeName
    let comparatorExpectedType =
      shouldIgnoreOptionalityMismatch ? expectedNonOptionalType : expectedType
    if normalizeTypeName(actualTypeName) != normalizeTypeName(comparatorExpectedType) {
      diagnostics.append(
        error(
          "validate found type mismatch for '\(entityName).\(expectedPropertyName)'. Expected '\(expectedType)', found '\(sourceProperty.typeName ?? "<missing>")'."
        )
      )
    }

    let expectedPersistentName =
      attribute.persistentName == expectedPropertyName ? nil : attribute.persistentName
    let actualPersistentName = sourceProperty.attribute?.persistentName
    if expectedPersistentName != actualPersistentName {
      diagnostics.append(
        error(
          "validate found persistentName mismatch for '\(entityName).\(expectedPropertyName)'. Expected '\(expectedPersistentName ?? "<none>")', found '\(actualPersistentName ?? "<none>")'.",
          fix: makeAttributeAnnotationFix(
            entityName: entityName,
            propertyName: expectedPropertyName,
            attribute: attribute,
            sourceProperty: sourceProperty
          )
        )
      )
    }

    let actualStorageMethod = sourceProperty.attribute?.storageMethod ?? .default
    if actualStorageMethod != attribute.storage.method {
      diagnostics.append(
        error(
          "validate found storageMethod mismatch for '\(entityName).\(expectedPropertyName)'. Expected '\(attribute.storage.method.rawValue)', found '\(actualStorageMethod.rawValue)'.",
          fix: makeAttributeAnnotationFix(
            entityName: entityName,
            propertyName: expectedPropertyName,
            attribute: attribute,
            sourceProperty: sourceProperty
          )
        )
      )
    }

    let actualUnique = sourceProperty.attribute?.isUnique ?? false
    if actualUnique != attribute.isUnique {
      diagnostics.append(
        error(
          "validate found unique mismatch for '\(entityName).\(expectedPropertyName)'. Expected '\(attribute.isUnique)', found '\(actualUnique)'.",
          fix: makeAttributeAnnotationFix(
            entityName: entityName,
            propertyName: expectedPropertyName,
            attribute: attribute,
            sourceProperty: sourceProperty
          )
        )
      )
    }

    let actualTransient = sourceProperty.attribute?.isTransient ?? false
    if actualTransient != attribute.isTransient {
      let expectedState = attribute.isTransient ? "transient" : "non-transient"
      let actualState = actualTransient ? "transient" : "non-transient"
      diagnostics.append(
        error(
          "validate found transient mismatch for '\(entityName).\(expectedPropertyName)'. Expected \(expectedState) source annotation, found \(actualState).",
          fix: makeAttributeAnnotationFix(
            entityName: entityName,
            propertyName: expectedPropertyName,
            attribute: attribute,
            sourceProperty: sourceProperty
          )
        )
      )
    }

    let actualTransformerName = resolveTransformerName(
      for: sourceProperty,
      sourceIR: sourceIR
    )
    if attribute.storage.method == .transformed,
      actualTransformerName != attribute.storage.transformerName
    {
      diagnostics.append(
        error(
          "validate found transformer mismatch for '\(entityName).\(expectedPropertyName)'. Expected '\(attribute.storage.transformerName ?? "<none>")', found '\(actualTransformerName ?? "<none>")'.",
          fix: makeAttributeAnnotationFix(
            entityName: entityName,
            propertyName: expectedPropertyName,
            attribute: attribute,
            sourceProperty: sourceProperty
          )
        )
      )
    }

    if shouldCompareDecodeFailurePolicy(for: attribute.storage.method) {
      let expectedPolicy = attribute.storage.decodeFailurePolicy ?? .fallbackToDefaultValue
      let actualPolicy = sourceProperty.attribute?.decodeFailurePolicy ?? .fallbackToDefaultValue
      if actualPolicy != expectedPolicy {
        diagnostics.append(
          error(
            "validate found decodeFailurePolicy mismatch for '\(entityName).\(expectedPropertyName)'. Expected '\(expectedPolicy.rawValue)', found '\(actualPolicy.rawValue)'.",
            fix: makeAttributeAnnotationFix(
              entityName: entityName,
              propertyName: expectedPropertyName,
              attribute: attribute,
              sourceProperty: sourceProperty
            )
          )
        )
      }
    }

    if attribute.isOptional {
      if let actualDefault = sourceProperty.defaultValueLiteral,
        normalizeLiteral(actualDefault) != "nil"
      {
        if attribute.storage.method == .codable
          || attribute.storage.method == .composition
          || attribute.storage.method == .transformed
        {
          diagnostics.append(
            error(
              "validate only allows nil as an explicit default for optional \(attribute.storage.method.rawValue) storage at '\(entityName).\(expectedPropertyName)'."
            )
          )
          return
        }
        diagnostics.append(
          error(
            "validate only allows optional persistent property '\(entityName).\(expectedPropertyName)' to omit a default or use nil.",
            fix: makeDefaultValueFix(
              entityName: entityName,
              propertyName: expectedPropertyName,
              sourceProperty: sourceProperty,
              replacementLiteral: "nil"
            )
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
            "validate found default value mismatch for '\(entityName).\(expectedPropertyName)'. Expected '\(attribute.modelDefaultValueLiteral ?? "<missing>")', found '\(sourceProperty.defaultValueLiteral ?? "<missing>")'.",
            fix: attribute.modelDefaultValueLiteral.flatMap {
              makeDefaultValueFix(
                entityName: entityName,
                propertyName: expectedPropertyName,
                sourceProperty: sourceProperty,
                replacementLiteral: $0
              )
            }
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

    guard let relationshipAnnotation = sourceProperty.relationship else {
      diagnostics.append(
        error(
          "validate requires explicit @Relationship(inverse:deleteRule:) for relationship '\(entityName).\(relationship.swiftName)'.",
          fix: makeRelationshipAnnotationFix(
            entityName: entityName,
            relationship: relationship,
            sourceProperty: sourceProperty
          )
        )
      )
      return
    }

    compareRelationshipAnnotation(
      entityName: entityName,
      relationship: relationship,
      sourceProperty: sourceProperty,
      relationshipAnnotation: relationshipAnnotation,
      diagnostics: &diagnostics
    )
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

  private static func compareRelationshipAnnotation(
    entityName: String,
    relationship: ToolingRelationshipIR,
    sourceProperty: ToolingSourcePropertyIR,
    relationshipAnnotation: ToolingSourceRelationshipAnnotationIR,
    diagnostics: inout [ToolingDiagnostic]
  ) {
    let expectedPersistentName =
      relationship.persistentName == relationship.swiftName ? nil : relationship.persistentName
    if relationshipAnnotation.persistentName != expectedPersistentName {
      diagnostics.append(
        error(
          "validate found relationship persistentName mismatch for '\(entityName).\(sourceProperty.name)'. Expected '\(expectedPersistentName ?? "<none>")', found '\(relationshipAnnotation.persistentName ?? "<none>")'.",
          fix: makeRelationshipAnnotationFix(
            entityName: entityName,
            relationship: relationship,
            sourceProperty: sourceProperty
          )
        )
      )
    }

    guard let expectedInverseName = relationship.inverseRelationshipName else {
      assertionFailure(
        "Validation should not compare relationship annotations for relationships without inverse metadata."
      )
      diagnostics.append(
        error(
          "validate found incomplete model inverse metadata for '\(entityName).\(relationship.swiftName)'."
        )
      )
      return
    }

    if relationshipAnnotation.inversePropertyName != expectedInverseName {
      diagnostics.append(
        error(
          "validate found inverse name mismatch for '\(entityName).\(relationship.swiftName)'. Expected '\(expectedInverseName)', found '\(relationshipAnnotation.inversePropertyName)'.",
          fix: makeRelationshipAnnotationFix(
            entityName: entityName,
            relationship: relationship,
            sourceProperty: sourceProperty
          )
        )
      )
    }

    if relationshipAnnotation.deleteRule != relationship.deleteRule {
      diagnostics.append(
        error(
          "validate found deleteRule mismatch for '\(entityName).\(relationship.swiftName)'. Expected '\(relationship.deleteRule)', found '\(relationshipAnnotation.deleteRule)'.",
          fix: makeRelationshipAnnotationFix(
            entityName: entityName,
            relationship: relationship,
            sourceProperty: sourceProperty
          )
        )
      )
    }

    let expectedMinimumModelCount = defaultMinimumModelCount(for: relationship)
    let actualMinimumModelCount =
      relationshipAnnotation.minimumModelCount ?? expectedMinimumModelCount
    if actualMinimumModelCount != relationship.minCount {
      diagnostics.append(
        error(
          "validate found minimumModelCount mismatch for '\(entityName).\(relationship.swiftName)'. Expected '\(relationship.minCount)', found '\(actualMinimumModelCount)'.",
          fix: makeRelationshipAnnotationFix(
            entityName: entityName,
            relationship: relationship,
            sourceProperty: sourceProperty
          )
        )
      )
    }

    let expectedMaximumModelCount = defaultMaximumModelCount(for: relationship)
    let actualMaximumModelCount =
      relationshipAnnotation.maximumModelCount ?? expectedMaximumModelCount
    if actualMaximumModelCount != relationship.maxCount {
      diagnostics.append(
        error(
          "validate found maximumModelCount mismatch for '\(entityName).\(relationship.swiftName)'. Expected '\(relationship.maxCount)', found '\(actualMaximumModelCount)'.",
          fix: makeRelationshipAnnotationFix(
            entityName: entityName,
            relationship: relationship,
            sourceProperty: sourceProperty
          )
        )
      )
    }
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

  private static func makeAttributeAnnotationFix(
    entityName: String,
    propertyName: String,
    attribute: ToolingAttributeIR,
    sourceProperty: ToolingSourcePropertyIR
  ) -> ToolingFixSuggestion? {
    guard
      let annotationText = renderExpectedAttributeAnnotation(
        expectedPropertyName: propertyName,
        attribute: attribute
      )
    else {
      return nil
    }

    let edit: ToolingTextEdit
    if let actualAttribute = sourceProperty.attribute {
      edit = .init(
        filePath: sourceProperty.filePath,
        range: actualAttribute.range,
        replacement: annotationText
      )
    } else {
      edit = .init(
        filePath: sourceProperty.filePath,
        range: .init(
          startUTF8Offset: sourceProperty.declarationRange.startUTF8Offset,
          endUTF8Offset: sourceProperty.declarationRange.startUTF8Offset
        ),
        replacement: "\(sourceProperty.declarationIndent)\(annotationText)\n"
      )
    }

    return .init(
      summary:
        "rewrite @Attribute for '\(entityName).\(propertyName)' to match model storage metadata",
      isSafeAutofix: true,
      edits: [edit]
    )
  }

  private static func makeRelationshipAnnotationFix(
    entityName: String,
    relationship: ToolingRelationshipIR,
    sourceProperty: ToolingSourcePropertyIR
  ) -> ToolingFixSuggestion? {
    guard let inverseName = relationship.inverseRelationshipName else {
      return nil
    }

    let annotationText = renderExpectedRelationshipAnnotation(
      inverseName: inverseName,
      relationship: relationship
    )

    let edit: ToolingTextEdit
    if let actualRelationship = sourceProperty.relationship {
      edit = .init(
        filePath: sourceProperty.filePath,
        range: actualRelationship.range,
        replacement: annotationText
      )
    } else {
      edit = .init(
        filePath: sourceProperty.filePath,
        range: .init(
          startUTF8Offset: sourceProperty.declarationRange.startUTF8Offset,
          endUTF8Offset: sourceProperty.declarationRange.startUTF8Offset
        ),
        replacement: "\(sourceProperty.declarationIndent)\(annotationText)\n"
      )
    }

    return .init(
      summary:
        "rewrite @Relationship for '\(entityName).\(relationship.swiftName)' to match relationship metadata",
      isSafeAutofix: true,
      edits: [edit]
    )
  }

  private static func renderExpectedRelationshipAnnotation(
    inverseName: String,
    relationship: ToolingRelationshipIR
  ) -> String {
    var arguments: [String] = []

    if relationship.persistentName != relationship.swiftName {
      arguments.append(#"persistentName: "\#(relationship.persistentName)""#)
    }
    arguments.append(#"inverse: "\#(inverseName)""#)
    arguments.append("deleteRule: .\(relationship.deleteRule)")

    if relationship.minCount != defaultMinimumModelCount(for: relationship) {
      arguments.append("minimumModelCount: \(relationship.minCount)")
    }
    if relationship.maxCount != defaultMaximumModelCount(for: relationship) {
      arguments.append("maximumModelCount: \(relationship.maxCount)")
    }

    return "@Relationship(\(arguments.joined(separator: ", ")))"
  }

  private static func defaultMinimumModelCount(for relationship: ToolingRelationshipIR) -> Int {
    relationship.isOptional ? 0 : 1
  }

  private static func defaultMaximumModelCount(for relationship: ToolingRelationshipIR) -> Int {
    switch relationship.cardinality {
    case .toOne:
      return 1
    case .toManyUnordered, .toManyOrdered:
      return 0
    }
  }

  private static func makeDefaultValueFix(
    entityName: String,
    propertyName: String,
    sourceProperty: ToolingSourcePropertyIR,
    replacementLiteral: String
  ) -> ToolingFixSuggestion? {
    guard let range = sourceProperty.defaultValueRange else {
      return nil
    }

    return .init(
      summary: "rewrite default value for '\(entityName).\(propertyName)'",
      isSafeAutofix: true,
      edits: [
        .init(
          filePath: sourceProperty.filePath,
          range: range,
          replacement: replacementLiteral
        )
      ]
    )
  }

  private static func renderExpectedAttributeAnnotation(
    expectedPropertyName: String,
    attribute: ToolingAttributeIR
  ) -> String? {
    let persistentName =
      attribute.persistentName == expectedPropertyName ? nil : attribute.persistentName

    var arguments: [String] = []
    if attribute.isUnique {
      arguments.append(".unique")
    }
    if attribute.isTransient {
      arguments.append(".transient")
    }
    if let persistentName {
      arguments.append(#"persistentName: "\#(persistentName)""#)
    }

    switch attribute.storage.method {
    case .default:
      break
    case .raw:
      arguments.append("storageMethod: .raw")
    case .codable:
      arguments.append("storageMethod: .codable")
    case .composition:
      arguments.append("storageMethod: .composition")
    case .transformed:
      guard let transformerName = attribute.storage.transformerName else {
        return nil
      }
      arguments.append(#"storageMethod: .transformed(name: "\#(transformerName)")"#)
    }

    if let decodeFailurePolicy = attribute.storage.decodeFailurePolicy {
      arguments.append("decodeFailurePolicy: .\(decodeFailurePolicy.rawValue)")
    }

    guard arguments.isEmpty == false else {
      return nil
    }
    return "@Attribute(\(arguments.joined(separator: ", ")))"
  }

  private static func error(
    _ message: String,
    fix: ToolingFixSuggestion? = nil
  ) -> ToolingDiagnostic {
    .init(severity: .error, code: .validationFailed, message: message, fix: fix)
  }

  private static func resolveTransformerName(
    for sourceProperty: ToolingSourcePropertyIR,
    sourceIR: ToolingSourceModelIR
  ) -> String? {
    if let transformerName = sourceProperty.attribute?.transformerName {
      return transformerName
    }
    guard let transformerTypeName = sourceProperty.attribute?.transformerTypeName else {
      return nil
    }
    return sourceIR.transformerRegistrations[transformerTypeName]
  }
}
