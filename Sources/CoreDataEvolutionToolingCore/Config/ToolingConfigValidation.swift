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

/// Validates config shape without needing a loaded Core Data model.
///
/// Use this when loading JSON from disk. These checks keep invalid combinations out of later
/// layers before any filesystem or Core Data work begins.
public func validateToolingConfigTemplate(_ template: ToolingConfigTemplate) throws {
  if let generate = template.generate {
    try validateGenerateTemplate(generate)
  }

  if let validate = template.validate {
    try validateValidateTemplate(validate)
  }
}

/// Validates config against a concrete Core Data model.
///
/// This second-stage validation checks that config references real entities/attributes and that
/// every persistent attribute can resolve to a concrete Swift type under the current rules.
public func validateToolingConfigTemplate(
  _ template: ToolingConfigTemplate,
  against model: NSManagedObjectModel
) throws {
  try validateToolingConfigTemplate(template)

  let entitiesByName: [String: NSEntityDescription] = Dictionary(
    uniqueKeysWithValues: model.entities.compactMap { entity in
      guard let name = entity.name else { return nil }
      return (name, entity)
    }
  )

  if let generate = template.generate {
    try validateAttributeRules(
      generate.attributeRules ?? .init(),
      context: "generate.attributeRules",
      entitiesByName: entitiesByName
    )
    try validateTypeResolutionCoverage(
      typeMappings: mergeToolingTypeMappings(generate.typeMappings),
      attributeRules: generate.attributeRules ?? .init(),
      context: "generate",
      entitiesByName: entitiesByName,
      defaultDecodeFailurePolicy: generate.defaultDecodeFailurePolicy ?? .fallbackToDefaultValue
    )
  }

  if let validate = template.validate {
    try validateAttributeRules(
      validate.attributeRules ?? .init(),
      context: "validate.attributeRules",
      entitiesByName: entitiesByName
    )
    try validateTypeResolutionCoverage(
      typeMappings: mergeToolingTypeMappings(validate.typeMappings),
      attributeRules: validate.attributeRules ?? .init(),
      context: "validate",
      entitiesByName: entitiesByName,
      defaultDecodeFailurePolicy: .fallbackToDefaultValue
    )
  }
}

/// Validates the `generate` section's self-contained rules and required fields.
private func validateGenerateTemplate(_ template: GenerateTemplate) throws {
  guard template.modelPath.isEmpty == false else {
    throw configValidationFailure("generate.modelPath must not be empty.")
  }
  guard template.outputDir.isEmpty == false else {
    throw configValidationFailure("generate.outputDir must not be empty.")
  }
  guard template.moduleName.isEmpty == false else {
    throw configValidationFailure("generate.moduleName must not be empty.")
  }
  if let modelVersion = template.modelVersion,
    modelVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  {
    throw configValidationFailure("generate.modelVersion must not be empty when provided.")
  }
  if let momcBin = template.momcBin,
    momcBin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  {
    throw configValidationFailure("generate.momcBin must not be empty when provided.")
  }
  if let headerTemplate = template.headerTemplate,
    headerTemplate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  {
    throw configValidationFailure("generate.headerTemplate must not be empty when provided.")
  }

  if template.singleFile == true, template.splitByEntity == true {
    throw configValidationFailure(
      "generate.singleFile and generate.splitByEntity cannot both be true."
    )
  }

  try validateTypeMappings(template.typeMappings, context: "generate.typeMappings")
  try validateAttributeRulesStatic(
    template.attributeRules,
    context: "generate.attributeRules",
    defaultDecodeFailurePolicy: template.defaultDecodeFailurePolicy ?? .fallbackToDefaultValue
  )
}

/// Validates the `validate` section's self-contained rules and required fields.
private func validateValidateTemplate(_ template: ValidateTemplate) throws {
  guard template.modelPath.isEmpty == false else {
    throw configValidationFailure("validate.modelPath must not be empty.")
  }
  guard template.sourceDir.isEmpty == false else {
    throw configValidationFailure("validate.sourceDir must not be empty.")
  }
  guard template.moduleName.isEmpty == false else {
    throw configValidationFailure("validate.moduleName must not be empty.")
  }
  if let modelVersion = template.modelVersion,
    modelVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  {
    throw configValidationFailure("validate.modelVersion must not be empty when provided.")
  }
  if let momcBin = template.momcBin,
    momcBin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  {
    throw configValidationFailure("validate.momcBin must not be empty when provided.")
  }
  if let maxIssues = template.maxIssues, maxIssues <= 0 {
    throw configValidationFailure("validate.maxIssues must be greater than zero.")
  }

  try validateTypeMappings(template.typeMappings, context: "validate.typeMappings")
  try validateAttributeRulesStatic(
    template.attributeRules,
    context: "validate.attributeRules",
    defaultDecodeFailurePolicy: .fallbackToDefaultValue
  )
}

/// Ensures `typeMappings` only uses known Core Data primitive keys and non-empty Swift types.
private func validateTypeMappings(
  _ mappings: ToolingTypeMappings?,
  context: String
) throws {
  guard let mappings else { return }

  let validKeys = Set(ToolingCoreDataPrimitiveType.allCases.map(\.rawValue))
  for (key, rule) in mappings.coreDataTypes {
    guard validKeys.contains(key) else {
      throw configValidationFailure(
        "\(context) contains unsupported Core Data primitive key '\(key)'."
      )
    }

    if rule.swiftType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      throw configValidationFailure(
        "\(context).\(key).swiftType must not be empty."
      )
    }
  }
}

/// Checks per-attribute rule combinations that can be validated without the model.
///
/// Examples:
/// - empty names/types are rejected
/// - `.transformed` requires `transformerType`
/// - `decodeFailurePolicy` is only valid for storage methods that can actually fail decoding
private func validateAttributeRulesStatic(
  _ rules: ToolingAttributeRules?,
  context: String,
  defaultDecodeFailurePolicy: ToolingDecodeFailurePolicy
) throws {
  guard let rules else { return }

  for (entityName, fields) in rules.entities {
    if entityName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      throw configValidationFailure("\(context) contains an empty entity name.")
    }

    for (fieldName, rule) in fields {
      if fieldName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        throw configValidationFailure("\(context).\(entityName) contains an empty field name.")
      }

      if let swiftName = rule.swiftName,
        swiftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      {
        throw configValidationFailure(
          "\(context).\(entityName).\(fieldName).swiftName must not be empty.")
      }

      if let swiftType = rule.swiftType,
        swiftType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      {
        throw configValidationFailure(
          "\(context).\(entityName).\(fieldName).swiftType must not be empty.")
      }

      if let transformerType = rule.transformerType,
        transformerType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      {
        throw configValidationFailure(
          "\(context).\(entityName).\(fieldName).transformerType must not be empty."
        )
      }

      let storageMethod = resolveToolingAttributeStorageMethod(rule)
      if storageMethod == .transformed, rule.transformerType == nil {
        throw configValidationFailure(
          "\(context).\(entityName).\(fieldName) uses storageMethod 'transformed' but does not provide transformerType."
        )
      }

      if rule.transformerType != nil, storageMethod != .transformed {
        throw configValidationFailure(
          "\(context).\(entityName).\(fieldName).transformerType is only valid with storageMethod 'transformed'."
        )
      }

      if rule.decodeFailurePolicy != nil {
        _ = resolveToolingDecodeFailurePolicy(
          rule,
          defaultPolicy: defaultDecodeFailurePolicy
        )
        switch storageMethod {
        case .raw, .codable, .transformed:
          break
        case .default, .composition:
          throw configValidationFailure(
            "\(context).\(entityName).\(fieldName).decodeFailurePolicy is only valid for raw, codable, or transformed storage."
          )
        }
      }
    }
  }
}

/// Ensures `attributeRules` only point at attributes that actually exist in the model.
private func validateAttributeRules(
  _ rules: ToolingAttributeRules,
  context: String,
  entitiesByName: [String: NSEntityDescription]
) throws {
  for (entityName, fields) in rules.entities {
    guard let entity = entitiesByName[entityName] else {
      throw configValidationFailure("\(context) references missing entity '\(entityName)'.")
    }

    for fieldName in fields.keys {
      guard entity.attributesByName[fieldName] != nil else {
        throw configValidationFailure(
          "\(context) references missing attribute '\(entityName).\(fieldName)'."
        )
      }
    }
  }
}

/// Verifies that each persistent attribute can resolve to a concrete Swift type.
///
/// Default storage goes through `typeMappings`; non-default storage methods must provide an
/// explicit `swiftType` so generation and drift validation stay deterministic.
private func validateTypeResolutionCoverage(
  typeMappings: ToolingTypeMappings,
  attributeRules: ToolingAttributeRules,
  context: String,
  entitiesByName: [String: NSEntityDescription],
  defaultDecodeFailurePolicy: ToolingDecodeFailurePolicy
) throws {
  for (entityName, entity) in entitiesByName {
    let entityRules = attributeRules[entity: entityName]
    for (fieldName, attribute) in entity.attributesByName {
      let rule = entityRules[fieldName] ?? .init()
      let storageMethod = resolveToolingAttributeStorageMethod(rule)
      _ = resolveToolingDecodeFailurePolicy(rule, defaultPolicy: defaultDecodeFailurePolicy)

      switch storageMethod {
      case .default:
        guard let mappingKey = toolingTypeMappingKey(for: attribute.attributeType) else {
          throw configValidationFailure(
            "\(context) cannot infer a default Swift type for '\(entityName).\(fieldName)'. Set attributeRules.\(entityName).\(fieldName).storageMethod explicitly."
          )
        }

        guard typeMappings[coreDataType: mappingKey] != nil else {
          throw configValidationFailure(
            "\(context).typeMappings does not provide a Swift type for Core Data primitive '\(mappingKey)'."
          )
        }
      case .raw, .codable, .composition:
        if rule.swiftType?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
          throw configValidationFailure(
            "\(context).attributeRules.\(entityName).\(fieldName).swiftType is required when storageMethod is '\(storageMethod.rawValue)'."
          )
        }
      case .transformed:
        if rule.swiftType?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
          throw configValidationFailure(
            "\(context).attributeRules.\(entityName).\(fieldName).swiftType is required when storageMethod is 'transformed'."
          )
        }
      }
    }
  }
}

private func configValidationFailure(_ message: String) -> ToolingFailure {
  .user(.configInvalid, message)
}
