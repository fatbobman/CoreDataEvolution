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

import CoreData
import Foundation

/// Errors raised while assembling a test/debug Core Data model from macro-emitted runtime schema.
public enum CDRuntimeModelBuilderError: LocalizedError, Sendable, Equatable {
  case emptyInput
  case duplicateEntityName(String)
  case unknownRelationshipTarget(
    entityName: String, relationshipName: String, targetTypeName: String)
  case ambiguousRelationshipTarget(
    entityName: String, relationshipName: String, targetTypeName: String)
  case missingInverse(entityName: String, relationshipName: String, targetEntityName: String)
  case ambiguousInverse(entityName: String, relationshipName: String, targetEntityName: String)
  case unsupportedRawBackingType(entityName: String, attributeName: String, backingTypeName: String)
  case unsupportedDefaultValueExpression(
    entityName: String,
    attributeName: String,
    expression: String,
    primitiveType: CDRuntimePrimitiveAttributeType
  )

  public var errorDescription: String? {
    switch self {
    case .emptyInput:
      return "runtime model builder requires at least one @PersistentModel type."
    case .duplicateEntityName(let name):
      return "runtime model builder found duplicate entity name '\(name)'."
    case .unknownRelationshipTarget(let entityName, let relationshipName, let targetTypeName):
      return
        "runtime model builder could not resolve relationship '\(entityName).\(relationshipName)' target '\(targetTypeName)'."
    case .ambiguousRelationshipTarget(let entityName, let relationshipName, let targetTypeName):
      return
        "runtime model builder found multiple target candidates for relationship '\(entityName).\(relationshipName)' and target type '\(targetTypeName)'."
    case .missingInverse(let entityName, let relationshipName, let targetEntityName):
      return
        "runtime model builder could not infer an inverse for relationship '\(entityName).\(relationshipName)' targeting '\(targetEntityName)'."
    case .ambiguousInverse(let entityName, let relationshipName, let targetEntityName):
      return
        "runtime model builder found multiple inverse candidates for relationship '\(entityName).\(relationshipName)' targeting '\(targetEntityName)'. Runtime schema currently requires a single unambiguous inverse relationship per source/target pair."
    case .unsupportedRawBackingType(let entityName, let attributeName, let backingTypeName):
      return
        "runtime model builder does not support raw backing type '\(backingTypeName)' for '\(entityName).\(attributeName)'."
    case .unsupportedDefaultValueExpression(
      let entityName,
      let attributeName,
      let expression,
      let primitiveType
    ):
      return
        "runtime model builder does not support default expression '\(expression)' for '\(entityName).\(attributeName)' with primitive type '\(primitiveType.rawValue)'."
    }
  }
}

/// Assembles `NSManagedObjectModel` from macro-emitted runtime schema.
/// The builder is intentionally scoped to test/debug workflows and uses pragmatic defaults where
/// the source macros do not yet model the full Core Data surface area.
///
/// Built models are cached by participating type list so repeated test/debug setup reuses the
/// same `NSManagedObjectModel` instance instead of rebuilding equivalent models over and over.
/// Model construction stays inside the cache lock on purpose so a single type list cannot race and
/// build the same schema multiple times under concurrent test setup.
public enum CDRuntimeModelBuilder {
  private static let cacheLock = NSLock()
  nonisolated(unsafe) private static var modelCache: [String: NSManagedObjectModel] = [:]

  /// Builds a Core Data model from macro-emitted runtime schema metadata.
  public static func makeModel(
    _ types: [any CDRuntimeSchemaProviding.Type]
  ) throws -> NSManagedObjectModel {
    guard types.isEmpty == false else {
      throw CDRuntimeModelBuilderError.emptyInput
    }

    let cacheKey = runtimeModelCacheKey(for: types)
    cacheLock.lock()
    defer { cacheLock.unlock() }
    if let cached = modelCache[cacheKey] {
      return cached
    }

    let schemas = CDRuntimeSchemaCollection.entitySchemas(types)
    let model = NSManagedObjectModel()
    var entitiesByName: [String: NSEntityDescription] = [:]
    var schemaByName: [String: CDRuntimeEntitySchema] = [:]
    var typeKeyToEntityNames: [String: Set<String>] = [:]

    for (index, schema) in schemas.enumerated() {
      guard entitiesByName[schema.entityName] == nil else {
        throw CDRuntimeModelBuilderError.duplicateEntityName(schema.entityName)
      }
      let entity = NSEntityDescription()
      entity.name = schema.entityName
      entity.managedObjectClassName = schema.managedObjectClassName
      model.entities.insert(entity, at: index)
      entitiesByName[schema.entityName] = entity
      schemaByName[schema.entityName] = schema

      let type = types[index]
      for key in typeLookupKeys(for: type, schema: schema) {
        typeKeyToEntityNames[key, default: []].insert(schema.entityName)
      }
    }

    var pendingRelationships: [(String, CDRuntimeRelationshipSchema, NSRelationshipDescription)] =
      []

    for schema in schemas {
      guard let entity = entitiesByName[schema.entityName] else { continue }
      var properties: [NSPropertyDescription] = []

      for attribute in schema.attributes {
        properties.append(
          try makeAttributeDescription(attribute, entityName: schema.entityName)
        )
      }

      for relationship in schema.relationships {
        let description = NSRelationshipDescription()
        description.name = relationship.persistentName
        description.minCount = relationship.isOptional ? 0 : 1
        switch relationship.kind {
        case .toOne:
          description.maxCount = 1
          description.isOrdered = false
        case .toManySet:
          description.maxCount = 0
          description.isOrdered = false
        case .toManyArray:
          description.maxCount = 0
          description.isOrdered = true
        }
        description.isOptional = relationship.isOptional
        description.deleteRule = .nullifyDeleteRule
        properties.append(description)
        pendingRelationships.append((schema.entityName, relationship, description))
      }

      entity.properties = properties
      if schema.uniquenessConstraints.isEmpty == false {
        entity.uniquenessConstraints = schema.uniquenessConstraints.map(\.persistentPropertyNames)
      }
    }

    for (entityName, relationship, description) in pendingRelationships {
      guard
        let targetEntityName = resolveTargetEntityName(
          for: relationship,
          typeKeyToEntityNames: typeKeyToEntityNames
        )
      else {
        let candidates = candidateEntityNames(
          for: relationship.targetTypeName,
          typeKeyToEntityNames: typeKeyToEntityNames
        )
        if candidates.isEmpty {
          throw CDRuntimeModelBuilderError.unknownRelationshipTarget(
            entityName: entityName,
            relationshipName: relationship.persistentName,
            targetTypeName: relationship.targetTypeName
          )
        }
        throw CDRuntimeModelBuilderError.ambiguousRelationshipTarget(
          entityName: entityName,
          relationshipName: relationship.persistentName,
          targetTypeName: relationship.targetTypeName
        )
      }

      guard let targetEntity = entitiesByName[targetEntityName] else {
        throw CDRuntimeModelBuilderError.unknownRelationshipTarget(
          entityName: entityName,
          relationshipName: relationship.persistentName,
          targetTypeName: relationship.targetTypeName
        )
      }
      description.destinationEntity = targetEntity

      let inverseName: String
      if let explicitInverseName = relationship.inverseName {
        inverseName = explicitInverseName
      } else {
        inverseName = try inferInverseName(
          sourceEntityName: entityName,
          relationship: relationship,
          targetEntityName: targetEntityName,
          schemaByName: schemaByName,
          typeKeyToEntityNames: typeKeyToEntityNames
        )
      }

      guard
        let inverse = targetEntity.propertiesByName[inverseName] as? NSRelationshipDescription
      else {
        throw CDRuntimeModelBuilderError.missingInverse(
          entityName: entityName,
          relationshipName: relationship.persistentName,
          targetEntityName: targetEntityName
        )
      }
      description.inverseRelationship = inverse
    }

    modelCache[cacheKey] = model
    return model
  }

  /// Variadic convenience for tests that keep the participating entity list inline.
  public static func makeModel(
    _ types: any CDRuntimeSchemaProviding.Type...
  ) throws -> NSManagedObjectModel {
    try makeModel(types)
  }

  private static func makeAttributeDescription(
    _ attribute: CDRuntimeAttributeSchema,
    entityName: String
  ) throws -> NSAttributeDescription {
    let description = NSAttributeDescription()
    description.name = attribute.persistentName
    description.isOptional = attribute.isOptional
    description.isTransient = attribute.isTransient

    switch attribute.storage {
    case .primitive(let primitive):
      description.attributeType = attributeType(for: primitive)
      if attribute.isTransient == false {
        description.defaultValue = try parsedDefaultValue(
          expression: attribute.defaultValueExpression,
          primitiveType: primitive,
          entityName: entityName,
          attributeName: attribute.persistentName
        )
      }
    case .raw(let backingTypeName):
      guard let primitive = primitiveType(forRawBackingTypeName: backingTypeName) else {
        throw CDRuntimeModelBuilderError.unsupportedRawBackingType(
          entityName: entityName,
          attributeName: attribute.persistentName,
          backingTypeName: backingTypeName
        )
      }
      description.attributeType = attributeType(for: primitive)
    case .codable:
      description.attributeType = .binaryDataAttributeType
    case .transformed(let transformerTypeName):
      description.attributeType = .transformableAttributeType
      description.valueTransformerName = transformerTypeName.replacingOccurrences(
        of: ".self",
        with: ""
      )
    case .composition:
      // Runtime schema models composition as one transformable dictionary payload. That matches the
      // macro-generated `@Attribute(storageMethod: .composition)` accessor contract, but it is not
      // equivalent to xcdatamodeld-side flattened fields and should remain test/debug-only.
      description.attributeType = .transformableAttributeType
      description.attributeValueClassName = NSStringFromClass(NSDictionary.self)
      description.valueTransformerName =
        NSValueTransformerName.secureUnarchiveFromDataTransformerName.rawValue
    }

    return description
  }

  private static func attributeType(
    for primitive: CDRuntimePrimitiveAttributeType
  ) -> NSAttributeType {
    switch primitive {
    case .string:
      return .stringAttributeType
    case .bool:
      return .booleanAttributeType
    case .int16:
      return .integer16AttributeType
    case .int32:
      return .integer32AttributeType
    case .int64:
      return .integer64AttributeType
    case .float:
      return .floatAttributeType
    case .double:
      return .doubleAttributeType
    case .decimal:
      return .decimalAttributeType
    case .date:
      return .dateAttributeType
    case .data:
      return .binaryDataAttributeType
    case .uuid:
      return .UUIDAttributeType
    case .url:
      return .URIAttributeType
    }
  }

  private static func primitiveType(
    forRawBackingTypeName typeName: String
  ) -> CDRuntimePrimitiveAttributeType? {
    switch typeName {
    case "String", "Swift.String":
      return .string
    case "Int16", "Swift.Int16":
      return .int16
    case "Int32", "Swift.Int32":
      return .int32
    case "Int", "Int64", "Swift.Int", "Swift.Int64":
      return .int64
    default:
      return nil
    }
  }

  private static func parsedDefaultValue(
    expression: String?,
    primitiveType: CDRuntimePrimitiveAttributeType,
    entityName: String,
    attributeName: String
  ) throws -> Any? {
    guard let expression, expression != "nil" else {
      return nil
    }

    switch primitiveType {
    case .string:
      guard expression.hasPrefix("\""), expression.hasSuffix("\"") else {
        throw unsupportedDefaultValue(
          entityName: entityName,
          attributeName: attributeName,
          expression: expression,
          primitiveType: primitiveType
        )
      }
      return String(expression.dropFirst().dropLast())
    case .bool:
      if expression == "true" { return true }
      if expression == "false" { return false }
      throw unsupportedDefaultValue(
        entityName: entityName,
        attributeName: attributeName,
        expression: expression,
        primitiveType: primitiveType
      )
    case .int16:
      guard let value = Int16(expression) else {
        throw unsupportedDefaultValue(
          entityName: entityName,
          attributeName: attributeName,
          expression: expression,
          primitiveType: primitiveType
        )
      }
      return value
    case .int32:
      guard let value = Int32(expression) else {
        throw unsupportedDefaultValue(
          entityName: entityName,
          attributeName: attributeName,
          expression: expression,
          primitiveType: primitiveType
        )
      }
      return value
    case .int64:
      guard let value = Int64(expression) else {
        throw unsupportedDefaultValue(
          entityName: entityName,
          attributeName: attributeName,
          expression: expression,
          primitiveType: primitiveType
        )
      }
      return value
    case .float:
      guard let value = Float(expression) else {
        throw unsupportedDefaultValue(
          entityName: entityName,
          attributeName: attributeName,
          expression: expression,
          primitiveType: primitiveType
        )
      }
      return value
    case .double:
      guard let value = Double(expression) else {
        throw unsupportedDefaultValue(
          entityName: entityName,
          attributeName: attributeName,
          expression: expression,
          primitiveType: primitiveType
        )
      }
      return value
    case .decimal:
      guard let value = Decimal(string: expression) else {
        throw unsupportedDefaultValue(
          entityName: entityName,
          attributeName: attributeName,
          expression: expression,
          primitiveType: primitiveType
        )
      }
      return value
    case .date:
      if expression == ".distantPast" || expression == "Date.distantPast" {
        return Date.distantPast
      }
      if expression == ".distantFuture" || expression == "Date.distantFuture" {
        return Date.distantFuture
      }
      if let interval = singleDoubleArgument(
        in: expression,
        functionNames: [
          "Date(timeIntervalSince1970:",
          ".init(timeIntervalSince1970:",
        ])
      {
        return Date(timeIntervalSince1970: interval)
      }
      if let interval = singleDoubleArgument(
        in: expression,
        functionNames: [
          "Date(timeIntervalSinceReferenceDate:",
          ".init(timeIntervalSinceReferenceDate:",
        ])
      {
        return Date(timeIntervalSinceReferenceDate: interval)
      }
      throw unsupportedDefaultValue(
        entityName: entityName,
        attributeName: attributeName,
        expression: expression,
        primitiveType: primitiveType
      )
    case .data:
      if expression == "Data()" || expression == ".init()" {
        return Data()
      }
      if let base64 = singleQuotedStringArgument(
        in: expression,
        functionNames: ["Data(base64Encoded:", ".init(base64Encoded:"]
      ) {
        guard let value = Data(base64Encoded: base64) else {
          throw unsupportedDefaultValue(
            entityName: entityName,
            attributeName: attributeName,
            expression: expression,
            primitiveType: primitiveType
          )
        }
        return value
      }
      throw unsupportedDefaultValue(
        entityName: entityName,
        attributeName: attributeName,
        expression: expression,
        primitiveType: primitiveType
      )
    case .uuid:
      if expression.hasPrefix("\""), expression.hasSuffix("\"") {
        guard let value = UUID(uuidString: String(expression.dropFirst().dropLast())) else {
          throw unsupportedDefaultValue(
            entityName: entityName,
            attributeName: attributeName,
            expression: expression,
            primitiveType: primitiveType
          )
        }
        return value
      }
      throw unsupportedDefaultValue(
        entityName: entityName,
        attributeName: attributeName,
        expression: expression,
        primitiveType: primitiveType
      )
    case .url:
      if expression.hasPrefix("\""), expression.hasSuffix("\"") {
        guard let value = URL(string: String(expression.dropFirst().dropLast())) else {
          throw unsupportedDefaultValue(
            entityName: entityName,
            attributeName: attributeName,
            expression: expression,
            primitiveType: primitiveType
          )
        }
        return value
      }
      if let argument = singleQuotedStringArgument(
        in: expression,
        functionNames: ["URL(string:"]
      ) {
        guard let value = URL(string: argument) else {
          throw unsupportedDefaultValue(
            entityName: entityName,
            attributeName: attributeName,
            expression: expression,
            primitiveType: primitiveType
          )
        }
        return value
      }
      if let argument = singleQuotedStringArgument(
        in: expression,
        functionNames: ["URL(fileURLWithPath:"]
      ) {
        return URL(fileURLWithPath: argument)
      }
      throw unsupportedDefaultValue(
        entityName: entityName,
        attributeName: attributeName,
        expression: expression,
        primitiveType: primitiveType
      )
    }
  }

  private static func inferInverseName(
    sourceEntityName: String,
    relationship: CDRuntimeRelationshipSchema,
    targetEntityName: String,
    schemaByName: [String: CDRuntimeEntitySchema],
    typeKeyToEntityNames: [String: Set<String>]
  ) throws -> String {
    // Runtime schema emitted from source declarations does not always carry explicit inverse names.
    // Inference keeps the happy path lightweight, but only supports a single candidate on the
    // target entity. If multiple relationships point back to the source entity, callers must
    // provide explicit `inverseName` metadata.
    guard let targetSchema = schemaByName[targetEntityName] else {
      throw CDRuntimeModelBuilderError.missingInverse(
        entityName: sourceEntityName,
        relationshipName: relationship.persistentName,
        targetEntityName: targetEntityName
      )
    }

    let candidates = targetSchema.relationships.filter { targetRelationship in
      guard
        let resolvedTarget = resolveTargetEntityName(
          for: targetRelationship,
          typeKeyToEntityNames: typeKeyToEntityNames
        )
      else {
        return false
      }
      return resolvedTarget == sourceEntityName
    }

    if candidates.isEmpty {
      throw CDRuntimeModelBuilderError.missingInverse(
        entityName: sourceEntityName,
        relationshipName: relationship.persistentName,
        targetEntityName: targetEntityName
      )
    }
    if candidates.count > 1 {
      throw CDRuntimeModelBuilderError.ambiguousInverse(
        entityName: sourceEntityName,
        relationshipName: relationship.persistentName,
        targetEntityName: targetEntityName
      )
    }
    return candidates[0].persistentName
  }

  private static func resolveTargetEntityName(
    for relationship: CDRuntimeRelationshipSchema,
    typeKeyToEntityNames: [String: Set<String>]
  ) -> String? {
    let candidates = candidateEntityNames(
      for: relationship.targetTypeName,
      typeKeyToEntityNames: typeKeyToEntityNames
    )
    return candidates.count == 1 ? candidates[0] : nil
  }

  private static func candidateEntityNames(
    for targetTypeName: String,
    typeKeyToEntityNames: [String: Set<String>]
  ) -> [String] {
    // Multiple runtime types may share the same short name across modules. Keep every candidate so
    // runtime-only model assembly fails with an explicit ambiguity instead of wiring to the last
    // inserted entity.
    let direct = Array(typeKeyToEntityNames[targetTypeName] ?? []).sorted()
    if direct.isEmpty == false {
      return direct
    }
    let suffix = ".\(targetTypeName)"
    return Array(
      Set(
        typeKeyToEntityNames.compactMap { key, values in
          key.hasSuffix(suffix) ? values : nil
        }.flatMap { $0 }
      )
    ).sorted()
  }

  private static func typeLookupKeys(
    for type: any CDRuntimeSchemaProviding.Type,
    schema: CDRuntimeEntitySchema
  ) -> [String] {
    [
      String(describing: type),
      String(reflecting: type),
      schema.entityName,
    ]
  }

  private static func runtimeModelCacheKey(
    for types: [any CDRuntimeSchemaProviding.Type]
  ) -> String {
    types.map { String(reflecting: $0) }.joined(separator: "|")
  }

  private static func unsupportedDefaultValue(
    entityName: String,
    attributeName: String,
    expression: String,
    primitiveType: CDRuntimePrimitiveAttributeType
  ) -> CDRuntimeModelBuilderError {
    .unsupportedDefaultValueExpression(
      entityName: entityName,
      attributeName: attributeName,
      expression: expression,
      primitiveType: primitiveType
    )
  }

  private static func singleQuotedStringArgument(
    in expression: String,
    functionNames: [String]
  ) -> String? {
    for functionName in functionNames {
      guard expression.hasPrefix(functionName), expression.hasSuffix(")") else { continue }
      let content = String(expression.dropFirst(functionName.count).dropLast())
        .trimmingCharacters(in: .whitespacesAndNewlines)
      guard content.hasPrefix("\""), content.hasSuffix("\"") else { return nil }
      return String(content.dropFirst().dropLast())
    }
    return nil
  }

  private static func singleDoubleArgument(
    in expression: String,
    functionNames: [String]
  ) -> Double? {
    for functionName in functionNames {
      guard expression.hasPrefix(functionName), expression.hasSuffix(")") else { continue }
      let content = String(expression.dropFirst(functionName.count).dropLast())
        .trimmingCharacters(in: .whitespacesAndNewlines)
      return Double(content)
    }
    return nil
  }
}

extension NSManagedObjectModel {
  /// Test/debug-only convenience for building a Core Data model from macro-generated runtime
  /// schema instead of `.xcdatamodeld`.
  public static func makeRuntimeModel(
    _ types: [any CDRuntimeSchemaProviding.Type]
  ) throws -> NSManagedObjectModel {
    try CDRuntimeModelBuilder.makeModel(types)
  }

  /// Variadic convenience overload for compact test/debug call sites.
  public static func makeRuntimeModel(
    _ types: any CDRuntimeSchemaProviding.Type...
  ) throws -> NSManagedObjectModel {
    try makeRuntimeModel(types)
  }
}
