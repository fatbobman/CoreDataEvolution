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

public struct ToolingTypeMappingRule: Codable, Sendable, Equatable {
  public let swiftType: String

  public init(swiftType: String) {
    self.swiftType = swiftType
  }
}

/// Maps Core Data primitive attribute types to default Swift property types.
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

public func makeDefaultToolingTypeMappings() -> ToolingTypeMappings {
  .init(
    coreDataTypes: [
      "Binary": .init(swiftType: "Data"),
      "Boolean": .init(swiftType: "Bool"),
      "Date": .init(swiftType: "Date"),
      "Decimal": .init(swiftType: "Decimal"),
      "Double": .init(swiftType: "Double"),
      "Float": .init(swiftType: "Float"),
      "Integer 16": .init(swiftType: "Int16"),
      "Integer 32": .init(swiftType: "Int32"),
      "Integer 64": .init(swiftType: "Int64"),
      "String": .init(swiftType: "String"),
      "URI": .init(swiftType: "URL"),
      "UUID": .init(swiftType: "UUID"),
    ]
  )
}
