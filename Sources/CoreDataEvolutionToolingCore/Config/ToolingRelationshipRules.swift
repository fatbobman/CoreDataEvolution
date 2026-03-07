//
//  ------------------------------------------------
//  Original project: CoreDataEvolution
//  Created on 2026/3/7 by Fatbobman(东坡肘子)
//  X: @fatbobman
//  Mastodon: @fatbobman@mastodon.social
//  GitHub: @fatbobman
//  Blog: https://fatbobman.com
//  ------------------------------------------------
//  Copyright © 2024-present Fatbobman. All rights reserved.

import Foundation

/// Optional per-relationship overrides consumed by `generate` and `validate`.
///
/// Relationship rules currently only rename the Swift-facing property. The inverse relationship's
/// Swift name is configured on the opposite entity's own rule entry. The `inverse:` annotation in
/// generated source continues to use the persistent relationship name from the Core Data model.
public struct ToolingRelationshipRule: Codable, Sendable, Equatable {
  public let swiftName: String?

  public init(swiftName: String? = nil) {
    self.swiftName = swiftName
  }
}

/// Maps entity persistent relationships to generation rules.
public struct ToolingRelationshipRules: Codable, Sendable, Equatable {
  public var entities: [String: [String: ToolingRelationshipRule]]

  public init(entities: [String: [String: ToolingRelationshipRule]] = [:]) {
    self.entities = entities
  }

  public subscript(entity entityName: String) -> [String: ToolingRelationshipRule] {
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
    var entities: [String: [String: ToolingRelationshipRule]] = [:]
    for key in container.allKeys {
      entities[key.stringValue] = try container.decode(
        [String: ToolingRelationshipRule].self,
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
