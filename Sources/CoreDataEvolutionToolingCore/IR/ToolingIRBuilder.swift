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
    var consumedRuleFieldsByEntity: [String: Set<String>] = [:]

    let entities = loadedModel.model.entities
      .compactMap { entity -> ToolingEntityIR? in
        guard let entityName = entity.name else { return nil }

        let entityRuleFields = request.attributeRules[entity: entityName]
        consumedRuleFieldsByEntity[entityName] = []

        let attributes = entity.attributesByName
          .sorted(by: { $0.key < $1.key })
          .map { persistentName, attribute in
            consumedRuleFieldsByEntity[entityName, default: []].insert(persistentName)
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
            buildRelationship(
              persistentName: persistentName,
              relationship: relationship
            )
          }

        let compositions =
          entityRuleFields
          .sorted(by: { $0.key < $1.key })
          .compactMap { persistentName, rule in
            buildCompositionPlaceholder(
              persistentName: persistentName,
              rule: rule
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
        consumedRuleFieldsByEntity: consumedRuleFieldsByEntity
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
      relationshipSetterPolicy: request.relationshipSetterPolicy,
      relationshipCountPolicy: request.relationshipCountPolicy,
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

    return .init(
      persistentName: persistentName,
      swiftName: swiftName,
      coreDataAttributeType: toolingCoreDataAttributeTypeName(for: attribute.attributeType),
      coreDataPrimitiveType: toolingTypeMappingKey(for: attribute.attributeType),
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
    persistentName: String,
    relationship: NSRelationshipDescription
  ) -> ToolingRelationshipIR {
    .init(
      persistentName: persistentName,
      swiftName: persistentName,
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

  private static func buildCompositionPlaceholder(
    persistentName: String,
    rule: ToolingAttributeRule
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
      persistentFields: [persistentName]
    )
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
    consumedRuleFieldsByEntity: [String: Set<String>]
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

      let consumedFields = consumedRuleFieldsByEntity[entityName] ?? []
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
