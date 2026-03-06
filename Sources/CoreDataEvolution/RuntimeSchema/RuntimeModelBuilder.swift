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
        "runtime model builder found multiple inverse candidates for relationship '\(entityName).\(relationshipName)' targeting '\(targetEntityName)'."
    case .unsupportedRawBackingType(let entityName, let attributeName, let backingTypeName):
      return
        "runtime model builder does not support raw backing type '\(backingTypeName)' for '\(entityName).\(attributeName)'."
    }
  }
}

/// Assembles `NSManagedObjectModel` from macro-emitted runtime schema.
/// The builder is intentionally scoped to test/debug workflows and uses pragmatic defaults where
/// the source macros do not yet model the full Core Data surface area.
public enum CDRuntimeModelBuilder {
  /// Builds a Core Data model from macro-emitted runtime schema metadata.
  public static func makeModel(
    _ types: [any CDRuntimeSchemaProviding.Type]
  ) throws -> NSManagedObjectModel {
    guard types.isEmpty == false else {
      throw CDRuntimeModelBuilderError.emptyInput
    }

    let schemas = CDRuntimeSchemaCollection.entitySchemas(types)
    let model = NSManagedObjectModel()
    var entitiesByName: [String: NSEntityDescription] = [:]
    var schemaByName: [String: CDRuntimeEntitySchema] = [:]
    var typeKeyToEntityName: [String: String] = [:]

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
        typeKeyToEntityName[key] = schema.entityName
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
          typeKeyToEntityName: typeKeyToEntityName
        )
      else {
        let candidates = candidateEntityNames(
          for: relationship.targetTypeName,
          typeKeyToEntityName: typeKeyToEntityName
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
          typeKeyToEntityName: typeKeyToEntityName
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

    switch attribute.storage {
    case .primitive(let primitive):
      description.attributeType = attributeType(for: primitive)
      description.defaultValue = parsedDefaultValue(
        expression: attribute.defaultValueExpression,
        primitiveType: primitive
      )
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
      // Test/debug runtime schema intentionally models composition as a transformable dictionary.
      // This preserves the macro-generated KVC accessor contract without requiring Xcode model files.
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
    primitiveType: CDRuntimePrimitiveAttributeType
  ) -> Any? {
    guard let expression, expression != "nil" else {
      return nil
    }

    switch primitiveType {
    case .string:
      guard expression.hasPrefix("\""), expression.hasSuffix("\"") else { return nil }
      return String(expression.dropFirst().dropLast())
    case .bool:
      return expression == "true" ? true : (expression == "false" ? false : nil)
    case .int16:
      return Int16(expression)
    case .int32:
      return Int32(expression)
    case .int64:
      return Int64(expression)
    case .float:
      return Float(expression)
    case .double:
      return Double(expression)
    case .decimal:
      return Decimal(string: expression)
    case .uuid:
      if expression.hasPrefix("\""), expression.hasSuffix("\"") {
        return UUID(uuidString: String(expression.dropFirst().dropLast()))
      }
      return nil
    case .url:
      if expression.hasPrefix("\""), expression.hasSuffix("\"") {
        return URL(string: String(expression.dropFirst().dropLast()))
      }
      return nil
    case .date, .data:
      return nil
    }
  }

  private static func inferInverseName(
    sourceEntityName: String,
    relationship: CDRuntimeRelationshipSchema,
    targetEntityName: String,
    schemaByName: [String: CDRuntimeEntitySchema],
    typeKeyToEntityName: [String: String]
  ) throws -> String {
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
          typeKeyToEntityName: typeKeyToEntityName
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
    typeKeyToEntityName: [String: String]
  ) -> String? {
    let candidates = candidateEntityNames(
      for: relationship.targetTypeName,
      typeKeyToEntityName: typeKeyToEntityName
    )
    return candidates.count == 1 ? candidates[0] : nil
  }

  private static func candidateEntityNames(
    for targetTypeName: String,
    typeKeyToEntityName: [String: String]
  ) -> [String] {
    let direct = typeKeyToEntityName[targetTypeName].map { [$0] } ?? []
    if direct.isEmpty == false {
      return direct
    }
    let suffix = ".\(targetTypeName)"
    return Array(
      Set(
        typeKeyToEntityName.compactMap { key, value in
          key.hasSuffix(suffix) ? value : nil
        }
      )
    )
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
