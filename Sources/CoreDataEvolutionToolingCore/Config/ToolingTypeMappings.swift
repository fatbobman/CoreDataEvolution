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

/// Describes the default Swift type chosen for one Core Data primitive type.
public struct ToolingTypeMappingRule: Codable, Sendable, Equatable {
  public let swiftType: String

  public init(swiftType: String) {
    self.swiftType = swiftType
  }
}

/// Maps Core Data primitive attribute types to default Swift property types.
///
/// Notes:
/// - These are default rules only. Per-attribute overrides should go in `attributeRules`.
/// - V1 intentionally uses exact-width defaults (`Integer 64 -> Int64`, `Float -> Float`).
///
/// Shape in JSON:
/// {
///   "Integer 64": {
///     "swiftType": "Int64"
///   },
///   "Float": {
///     "swiftType": "Float"
///   }
/// }
public struct ToolingTypeMappings: Codable, Sendable, Equatable {
  public var coreDataTypes: [String: ToolingTypeMappingRule]

  public init(coreDataTypes: [String: ToolingTypeMappingRule] = [:]) {
    self.coreDataTypes = coreDataTypes
  }

  public subscript(coreDataType typeName: String) -> ToolingTypeMappingRule? {
    coreDataTypes[typeName]
  }

  private struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }

    init?(stringValue: String) {
      self.stringValue = stringValue
    }

    init?(intValue _: Int) {
      return nil
    }
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: DynamicCodingKey.self)
    var coreDataTypes: [String: ToolingTypeMappingRule] = [:]
    for key in container.allKeys {
      coreDataTypes[key.stringValue] = try container.decode(
        ToolingTypeMappingRule.self,
        forKey: key
      )
    }
    self.coreDataTypes = coreDataTypes
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: DynamicCodingKey.self)
    for (typeName, rule) in coreDataTypes.sorted(by: { $0.key < $1.key }) {
      guard let key = DynamicCodingKey(stringValue: typeName) else { continue }
      try container.encode(rule, forKey: key)
    }
  }
}

/// Returns the built-in default mapping table used when config does not override it.
public func makeDefaultToolingTypeMappings() -> ToolingTypeMappings {
  .init(
    coreDataTypes: [
      ToolingCoreDataPrimitiveType.binary.rawValue: .init(swiftType: "Data"),
      ToolingCoreDataPrimitiveType.boolean.rawValue: .init(swiftType: "Bool"),
      ToolingCoreDataPrimitiveType.date.rawValue: .init(swiftType: "Date"),
      ToolingCoreDataPrimitiveType.decimal.rawValue: .init(swiftType: "Decimal"),
      ToolingCoreDataPrimitiveType.double.rawValue: .init(swiftType: "Double"),
      ToolingCoreDataPrimitiveType.float.rawValue: .init(swiftType: "Float"),
      ToolingCoreDataPrimitiveType.integer16.rawValue: .init(swiftType: "Int16"),
      ToolingCoreDataPrimitiveType.integer32.rawValue: .init(swiftType: "Int32"),
      ToolingCoreDataPrimitiveType.integer64.rawValue: .init(swiftType: "Int64"),
      ToolingCoreDataPrimitiveType.string.rawValue: .init(swiftType: "String"),
      ToolingCoreDataPrimitiveType.uri.rawValue: .init(swiftType: "URL"),
      ToolingCoreDataPrimitiveType.uuid.rawValue: .init(swiftType: "UUID"),
    ]
  )
}
