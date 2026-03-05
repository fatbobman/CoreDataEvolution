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

/// Maps Core Data persistent field names to generated Swift property names.
/// Shape in JSON:
/// {
///   "Item": {
///     "name": "title"
///   }
/// }
public struct ToolingAttributeMappings: Codable, Sendable, Equatable {
  public var entities: [String: [String: String]]

  public init(entities: [String: [String: String]] = [:]) {
    self.entities = entities
  }

  public subscript(entity entityName: String) -> [String: String] {
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
    var entities: [String: [String: String]] = [:]
    for key in container.allKeys {
      entities[key.stringValue] = try container.decode([String: String].self, forKey: key)
    }
    self.entities = entities
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: DynamicCodingKey.self)
    for (entity, mappings) in entities.sorted(by: { $0.key < $1.key }) {
      guard let key = DynamicCodingKey(stringValue: entity) else { continue }
      try container.encode(mappings, forKey: key)
    }
  }
}
