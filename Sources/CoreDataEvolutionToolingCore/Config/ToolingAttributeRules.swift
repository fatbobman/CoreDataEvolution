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

/// Mirrors the attribute storage strategies currently exposed by the macro layer.
public enum ToolingAttributeStorageRule: String, Codable, Sendable, Equatable {
  case `default`
  case raw
  case codable
  case composition
  case transformed
}

/// Optional per-attribute overrides consumed by `generate` and `validate`.
///
/// The rule only stores differences from model defaults. For example, if `swiftName`
/// is omitted, the consumer should treat the persistent field name as the Swift name.
public struct ToolingAttributeRule: Codable, Sendable, Equatable {
  public let swiftName: String?
  public let swiftType: String?
  public let storageMethod: ToolingAttributeStorageRule?
  public let transformerName: String?
  public let decodeFailurePolicy: ToolingDecodeFailurePolicy?
  /// Validate-only escape hatch for intentionally keeping source non-optional while the model
  /// field stays optional. Other drift dimensions remain checked as usual.
  public let ignoreOptionality: Bool?

  public init(
    swiftName: String? = nil,
    swiftType: String? = nil,
    storageMethod: ToolingAttributeStorageRule? = nil,
    transformerName: String? = nil,
    decodeFailurePolicy: ToolingDecodeFailurePolicy? = nil,
    ignoreOptionality: Bool? = nil
  ) {
    self.swiftName = swiftName
    self.swiftType = swiftType
    self.storageMethod = storageMethod
    self.transformerName = transformerName
    self.decodeFailurePolicy = decodeFailurePolicy
    self.ignoreOptionality = ignoreOptionality
  }
}

/// Maps entity persistent fields to generation rules.
///
/// Notes:
/// - The first key is the entity name.
/// - The second key is the persistent field name from the Core Data model.
/// - Consumers should resolve `swiftName ?? persistentField`.
///
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
