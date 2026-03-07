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

/// Optional per-composition-field overrides keyed by the persistent leaf field name.
///
/// This is intentionally separate from `attributeRules` because composition leaf renames belong to
/// the source-side value type, not to the top-level Core Data entity property.
public struct ToolingCompositionFieldRule: Codable, Sendable, Equatable {
  public let swiftName: String?

  public init(swiftName: String? = nil) {
    self.swiftName = swiftName
  }
}

/// Maps composition Swift types to per-leaf rename rules.
///
/// Shape in JSON:
/// {
///   "ItemLocation": {
///     "lat": { "swiftName": "latitude" },
///     "lng": { "swiftName": "longitude" }
///   }
/// }
///
/// Current tooling can validate the composition type name and leaf rename values, but it does not
/// yet parse standalone `@Composition` declarations. That means config validation can confirm that
/// a rule targets a composition Swift type used by some `.composition` attribute, but it cannot
/// prove that every persistent leaf field key exists in the source-side composition definition.
public struct ToolingCompositionRules: Codable, Sendable, Equatable {
  public var types: [String: [String: ToolingCompositionFieldRule]]

  public init(types: [String: [String: ToolingCompositionFieldRule]] = [:]) {
    self.types = types
  }

  public subscript(type typeName: String) -> [String: ToolingCompositionFieldRule] {
    types[typeName] ?? [:]
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
    var types: [String: [String: ToolingCompositionFieldRule]] = [:]
    for key in container.allKeys {
      types[key.stringValue] = try container.decode(
        [String: ToolingCompositionFieldRule].self,
        forKey: key
      )
    }
    self.types = types
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: DynamicCodingKey.self)
    for (typeName, rules) in types.sorted(by: { $0.key < $1.key }) {
      guard let key = DynamicCodingKey(stringValue: typeName) else { continue }
      try container.encode(rules, forKey: key)
    }
  }
}
