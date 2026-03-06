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

/// Canonical keys used by `typeMappings`.
///
/// Keep this mapping centralized so bootstrap, validation, and future IR/generate code all use
/// the same string vocabulary for Core Data primitive types.
public enum ToolingCoreDataPrimitiveType: String, CaseIterable, Sendable {
  case binary = "Binary"
  case boolean = "Boolean"
  case date = "Date"
  case decimal = "Decimal"
  case double = "Double"
  case float = "Float"
  case integer16 = "Integer 16"
  case integer32 = "Integer 32"
  case integer64 = "Integer 64"
  case string = "String"
  case uri = "URI"
  case uuid = "UUID"

  public init?(attributeType: NSAttributeType) {
    switch attributeType {
    case .binaryDataAttributeType:
      self = .binary
    case .booleanAttributeType:
      self = .boolean
    case .dateAttributeType:
      self = .date
    case .decimalAttributeType:
      self = .decimal
    case .doubleAttributeType:
      self = .double
    case .floatAttributeType:
      self = .float
    case .integer16AttributeType:
      self = .integer16
    case .integer32AttributeType:
      self = .integer32
    case .integer64AttributeType:
      self = .integer64
    case .stringAttributeType:
      self = .string
    case .URIAttributeType:
      self = .uri
    case .UUIDAttributeType:
      self = .uuid
    default:
      return nil
    }
  }
}

public func toolingTypeMappingKey(for attributeType: NSAttributeType) -> String? {
  ToolingCoreDataPrimitiveType(attributeType: attributeType)?.rawValue
}

/// Returns a stable human-readable Core Data attribute type name for inspect output and
/// diagnostics.
///
/// This helper lives next to the primitive-type mapping because both functions translate
/// `NSAttributeType` into the tooling's Core Data vocabulary. The primitive mapping is only a
/// subset; inspect still needs names for non-primitive cases such as Transformable and Composite.
public func toolingCoreDataAttributeTypeName(for attributeType: NSAttributeType) -> String {
  switch attributeType {
  case .undefinedAttributeType:
    return "Undefined"
  case .integer16AttributeType:
    return "Integer 16"
  case .integer32AttributeType:
    return "Integer 32"
  case .integer64AttributeType:
    return "Integer 64"
  case .decimalAttributeType:
    return "Decimal"
  case .doubleAttributeType:
    return "Double"
  case .floatAttributeType:
    return "Float"
  case .stringAttributeType:
    return "String"
  case .booleanAttributeType:
    return "Boolean"
  case .dateAttributeType:
    return "Date"
  case .binaryDataAttributeType:
    return "Binary"
  case .UUIDAttributeType:
    return "UUID"
  case .URIAttributeType:
    return "URI"
  case .transformableAttributeType:
    return "Transformable"
  case .objectIDAttributeType:
    return "ObjectID"
  case .compositeAttributeType:
    return "Composite"
  @unknown default:
    return "Unknown"
  }
}
