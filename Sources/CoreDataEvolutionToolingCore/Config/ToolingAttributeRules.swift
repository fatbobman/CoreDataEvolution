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

public enum ToolingAttributeStorageRule: String, Codable, Sendable, Equatable {
  case `default`
  case raw
  case codable
  case composition
  case transformed
}

public struct ToolingAttributeRule: Codable, Sendable, Equatable {
  public let swiftName: String?
  public let swiftType: String?
  public let storageMethod: ToolingAttributeStorageRule?
  public let transformerType: String?
  public let decodeFailurePolicy: ToolingDecodeFailurePolicy?

  public init(
    swiftName: String? = nil,
    swiftType: String? = nil,
    storageMethod: ToolingAttributeStorageRule? = nil,
    transformerType: String? = nil,
    decodeFailurePolicy: ToolingDecodeFailurePolicy? = nil
  ) {
    self.swiftName = swiftName
    self.swiftType = swiftType
    self.storageMethod = storageMethod
    self.transformerType = transformerType
    self.decodeFailurePolicy = decodeFailurePolicy
  }
}

/// Maps entity persistent fields to generation rules.
/// Shape in JSON:
/// {
///   "Item": {
///     "name": {
///       "swiftName": "title"
///     },
///     "status_raw": {
///       "swiftType": "ItemStatus",
///       "storageMethod": "raw"
///     }
///   }
/// }
public struct ToolingAttributeRules: Codable, Sendable, Equatable {
  public var entities: [String: [String: ToolingAttributeRule]]

  public init(entities: [String: [String: ToolingAttributeRule]] = [:]) {
    self.entities = entities
  }

  public subscript(entity entityName: String) -> [String: ToolingAttributeRule] {
    entities[entityName] ?? [:]
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
    var entities: [String: [String: ToolingAttributeRule]] = [:]
    for key in container.allKeys {
      entities[key.stringValue] = try container.decode(
        [String: ToolingAttributeRule].self,
        forKey: key
      )
    }
    self.entities = entities
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: DynamicCodingKey.self)
    for (entity, rules) in entities.sorted(by: { $0.key < $1.key }) {
      guard let key = DynamicCodingKey(stringValue: entity) else { continue }
      try container.encode(rules, forKey: key)
    }
  }
}
