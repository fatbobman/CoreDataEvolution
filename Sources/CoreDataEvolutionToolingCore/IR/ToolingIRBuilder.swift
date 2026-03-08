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
import Foundation

/// Builds serializable IR from a loaded Core Data model plus resolved tooling rules.
public enum ToolingIRBuilder {
  public static func build(
    from loadedModel: ToolingLoadedModel,
    request: InspectRequest
  ) -> (modelIR: ToolingModelIR, diagnostics: [ToolingDiagnostic]) {
    var diagnostics: [ToolingDiagnostic] = []
    var consumedAttributeRuleFieldsByEntity: [String: Set<String>] = [:]
    var consumedRelationshipRuleFieldsByEntity: [String: Set<String>] = [:]

    let entities = loadedModel.model.entities
      .compactMap { entity -> ToolingEntityIR? in
        guard let entityName = entity.name else { return nil }

        let entityRuleFields = request.attributeRules[entity: entityName]
        consumedAttributeRuleFieldsByEntity[entityName] = []
        consumedRelationshipRuleFieldsByEntity[entityName] = []

        let attributes = entity.attributesByName
          .sorted(by: { $0.key < $1.key })
          .map { persistentName, attribute in
            consumedAttributeRuleFieldsByEntity[entityName, default: []].insert(persistentName)
            return buildAttribute(
              entityName: entityName,
              persistentName: persistentName,
              attribute: attribute,
              request: request,
              diagnostics: &diagnostics
            )
          }

        let relationships = entity.relationshipsByName
          .sorted(by: { $0.key < $1.key })
          .map { persistentName, relationship in
            consumedRelationshipRuleFieldsByEntity[entityName, default: []].insert(persistentName)
            return buildRelationship(
              entityName: entityName,
              persistentName: persistentName,
              relationship: relationship,
              request: request
            )
          }

        let compositions =
          entityRuleFields
          .sorted(by: { $0.key < $1.key })
          .compactMap { persistentName, rule in
            buildCompositionPlaceholder(
              persistentName: persistentName,
              rule: rule,
              request: request
            )
          }

        return .init(
          name: entityName,
          managedObjectClassName: entity.managedObjectClassName,
          representedClassName: entity.name,
          attributes: attributes,
          relationships: relationships,
          compositions: compositions
        )
      }
      .sorted(by: { $0.name < $1.name })

    diagnostics.append(
      contentsOf: makeUnusedRuleDiagnostics(
        model: loadedModel.model,
        request: request,
        consumedAttributeRuleFieldsByEntity: consumedAttributeRuleFieldsByEntity,
        consumedRelationshipRuleFieldsByEntity: consumedRelationshipRuleFieldsByEntity
      )
    )

    let source = ToolingModelSourceIR(
      originalPath: loadedModel.resolvedInput.originalURL.path,
      selectedSourcePath: loadedModel.resolvedInput.selectedSourceURL.path,
      compiledModelPath: loadedModel.resolvedInput.compiledModelURL.path,
      inputKind: loadedModel.resolvedInput.kind,
      selectedVersionName: loadedModel.resolvedInput.selectedVersionName
    )

    let generationPolicy = ToolingGenerationPolicyIR(
      accessLevel: request.accessLevel,
      singleFile: request.singleFile,
      splitByEntity: request.splitByEntity,
      generateInit: request.generateInit,
      defaultDecodeFailurePolicy: request.defaultDecodeFailurePolicy
    )

    return (
      .init(
        source: source,
        generationPolicy: generationPolicy,
        entities: entities
      ),
      diagnostics
    )
  }

  // Attribute IR is built in best-effort mode so inspect can surface partially-complete configs.
  private static func buildAttribute(
    entityName: String,
    persistentName: String,
    attribute: NSAttributeDescription,
    request: InspectRequest,
    diagnostics: inout [ToolingDiagnostic]
  ) -> ToolingAttributeIR {
    let rule = request.attributeRules[entity: entityName][persistentName] ?? .init()
    let storageMethod = resolveToolingAttributeStorageMethod(rule)
    let modelDefaultValueLiteral = toolingModelDefaultValueLiteral(for: attribute)
    let swiftName = resolveToolingSwiftName(
      persistentName: persistentName,
      rule: rule
    )
    let decodeFailurePolicy =
      shouldAttachDecodeFailurePolicy(
        for: storageMethod
      )
      ? resolveToolingDecodeFailurePolicy(
        rule,
        defaultPolicy: request.defaultDecodeFailurePolicy
      ) : nil

    let resolvedType = resolveSwiftType(
      entityName: entityName,
      persistentName: persistentName,
      attribute: attribute,
      storageMethod: storageMethod,
      request: request,
      diagnostics: &diagnostics
    )

    let isUnique = isSingleFieldUnique(
      attributePersistentName: persistentName,
      in: attribute.entity
    )

    return .init(
      persistentName: persistentName,
      swiftName: swiftName,
      coreDataAttributeType: toolingCoreDataAttributeTypeName(for: attribute.attributeType),
      coreDataPrimitiveType: toolingTypeMappingKey(for: attribute.attributeType),
      isUnique: isUnique,
      isTransient: attribute.isTransient,
      isOptional: attribute.isOptional,
      hasModelDefaultValue: attribute.defaultValue != nil,
      modelDefaultValueLiteral: modelDefaultValueLiteral,
      storage: .init(
        method: storageMethod,
        swiftType: makeOptionalAwareSwiftType(
          nonOptionalType: resolvedType,
          isOptional: attribute.isOptional
        ),
        nonOptionalSwiftType: resolvedType,
        transformerType: rule.transformerType,
        decodeFailurePolicy: decodeFailurePolicy,
        isResolved: resolvedType != nil
      )
    )
  }

  private static func buildRelationship(
    entityName: String,
    persistentName: String,
    relationship: NSRelationshipDescription,
    request: InspectRequest
  ) -> ToolingRelationshipIR {
    let rule =
      request.relationshipRules[entity: entityName][persistentName]
      ?? ToolingRelationshipRule()
    return .init(
      persistentName: persistentName,
      swiftName: resolveToolingRelationshipSwiftName(
        persistentName: persistentName,
        rule: rule
      ),
      destinationEntityName: relationship.destinationEntity?.name,
      inverseRelationshipName: relationship.inverseRelationship?.name,
      cardinality: relationship.isToMany
        ? (relationship.isOrdered ? .toManyOrdered : .toManyUnordered)
        : .toOne,
      isOptional: relationship.isOptional,
      minCount: relationship.minCount,
      maxCount: relationship.maxCount,
      deleteRule: toolingDeleteRuleName(for: relationship.deleteRule)
    )
  }

  private static func isSingleFieldUnique(
    attributePersistentName: String,
    in entity: NSEntityDescription?
  ) -> Bool {
    guard let entity else { return false }
    return entity.uniquenessConstraints.contains { constraint in
      let names = constraint.compactMap { $0 as? String }
      return names == [attributePersistentName]
    }
  }

  private static func buildCompositionPlaceholder(
    persistentName: String,
    rule: ToolingAttributeRule,
    request: InspectRequest
  ) -> ToolingCompositionIR? {
    guard resolveToolingAttributeStorageMethod(rule) == .composition,
      let swiftType = rule.swiftType
    else {
      return nil
    }

    return .init(
      swiftName: resolveToolingSwiftName(
        persistentName: persistentName,
        rule: rule
      ),
      swiftType: swiftType,
      persistentFields: [persistentName],
      fieldRules: makeCompositionFieldRules(
        compositionTypeName: swiftType,
        request: request
      )
    )
  }

  private static func makeCompositionFieldRules(
    compositionTypeName: String,
    request: InspectRequest
  ) -> [ToolingCompositionFieldIR] {
    request.compositionRules[type: compositionTypeName]
      .sorted(by: { $0.key < $1.key })
      .compactMap { persistentFieldName, rule in
        let swiftName = rule.swiftName ?? persistentFieldName
        guard swiftName.isEmpty == false else {
          return nil
        }
        return .init(
          persistentName: persistentFieldName,
          swiftName: swiftName
        )
      }
  }

  private static func resolveSwiftType(
    entityName: String,
    persistentName: String,
    attribute: NSAttributeDescription,
    storageMethod: ToolingAttributeStorageRule,
    request: InspectRequest,
    diagnostics: inout [ToolingDiagnostic]
  ) -> String? {
    let rule = request.attributeRules[entity: entityName][persistentName] ?? .init()

    switch storageMethod {
    case .default:
      guard let mappingKey = toolingTypeMappingKey(for: attribute.attributeType) else {
        diagnostics.append(
          .init(
            severity: .warning,
            code: .configInvalid,
            message:
              "inspect could not infer a default Swift type for '\(entityName).\(persistentName)'.",
            hint:
              "Set attributeRules.\(entityName).\(persistentName).storageMethod and swiftType explicitly."
          )
        )
        return nil
      }

      guard let swiftType = request.typeMappings[coreDataType: mappingKey]?.swiftType else {
        diagnostics.append(
          .init(
            severity: .warning,
            code: .configInvalid,
            message:
              "inspect could not resolve typeMappings['\(mappingKey)'] for '\(entityName).\(persistentName)'.",
            hint:
              "Add a typeMappings override or choose an explicit storageMethod for this field."
          )
        )
        return nil
      }

      return swiftType
    case .raw, .codable, .composition, .transformed:
      guard let swiftType = rule.swiftType else {
        diagnostics.append(
          .init(
            severity: .warning,
            code: .configInvalid,
            message:
              "inspect found storageMethod '\(storageMethod.rawValue)' for '\(entityName).\(persistentName)' without a resolved swiftType.",
            hint:
              "Set attributeRules.\(entityName).\(persistentName).swiftType before generate/validate."
          )
        )
        return nil
      }

      return swiftType
    }
  }

  private static func makeUnusedRuleDiagnostics(
    model: NSManagedObjectModel,
    request: InspectRequest,
    consumedAttributeRuleFieldsByEntity: [String: Set<String>],
    consumedRelationshipRuleFieldsByEntity: [String: Set<String>]
  ) -> [ToolingDiagnostic] {
    let modelEntityNames = Set(model.entities.compactMap(\.name))
    var diagnostics: [ToolingDiagnostic] = []

    for (entityName, fields) in request.attributeRules.entities.sorted(by: { $0.key < $1.key }) {
      guard modelEntityNames.contains(entityName) else {
        diagnostics.append(
          .init(
            severity: .warning,
            code: .configInvalid,
            message: "inspect found attributeRules for missing entity '\(entityName)'."
          )
        )
        continue
      }

      let consumedFields = consumedAttributeRuleFieldsByEntity[entityName] ?? []
      let unusedFields = fields.keys
        .filter { consumedFields.contains($0) == false }
        .sorted()

      for fieldName in unusedFields {
        diagnostics.append(
          .init(
            severity: .warning,
            code: .configInvalid,
            message:
              "inspect found attributeRules for missing attribute '\(entityName).\(fieldName)'."
          )
        )
      }
    }

    for (entityName, fields) in request.relationshipRules.entities.sorted(by: { $0.key < $1.key }) {
      guard modelEntityNames.contains(entityName) else {
        diagnostics.append(
          .init(
            severity: .warning,
            code: .configInvalid,
            message: "inspect found relationshipRules for missing entity '\(entityName)'."
          )
        )
        continue
      }

      let consumedFields = consumedRelationshipRuleFieldsByEntity[entityName] ?? []
      let unusedFields = fields.keys
        .filter { consumedFields.contains($0) == false }
        .sorted()

      for fieldName in unusedFields {
        diagnostics.append(
          .init(
            severity: .warning,
            code: .configInvalid,
            message:
              "inspect found relationshipRules for missing relationship '\(entityName).\(fieldName)'."
          )
        )
      }
    }

    return diagnostics
  }

  private static func makeOptionalAwareSwiftType(
    nonOptionalType: String?,
    isOptional: Bool
  ) -> String? {
    guard let nonOptionalType else { return nil }
    return isOptional ? "\(nonOptionalType)?" : nonOptionalType
  }

  private static func shouldAttachDecodeFailurePolicy(
    for storageMethod: ToolingAttributeStorageRule
  ) -> Bool {
    switch storageMethod {
    case .raw, .codable, .transformed:
      return true
    case .default, .composition:
      return false
    }
  }
}

private func toolingDeleteRuleName(for deleteRule: NSDeleteRule) -> String {
  switch deleteRule {
  case .noActionDeleteRule:
    return "noAction"
  case .nullifyDeleteRule:
    return "nullify"
  case .cascadeDeleteRule:
    return "cascade"
  case .denyDeleteRule:
    return "deny"
  @unknown default:
    return "unknown"
  }
}
