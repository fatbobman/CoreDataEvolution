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

/// `nil` means "follow the default persistent-attribute path".
public func resolveToolingAttributeStorageMethod(
  _ rule: ToolingAttributeRule
) -> ToolingAttributeStorageRule {
  rule.storageMethod ?? .default
}

/// Attribute-level policy always wins over the request-level default.
public func resolveToolingDecodeFailurePolicy(
  _ rule: ToolingAttributeRule,
  defaultPolicy: ToolingDecodeFailurePolicy
) -> ToolingDecodeFailurePolicy {
  rule.decodeFailurePolicy ?? defaultPolicy
}

public func resolveToolingSwiftName(
  persistentName: String,
  rule: ToolingAttributeRule
) -> String {
  rule.swiftName ?? persistentName
}

public func resolveToolingRelationshipSwiftName(
  persistentName: String,
  rule: ToolingRelationshipRule
) -> String {
  rule.swiftName ?? persistentName
}

/// Config files are allowed to provide partial overrides. Missing primitive keys inherit the
/// built-in defaults instead of erasing them.
public func mergeToolingTypeMappings(
  _ overrides: ToolingTypeMappings?
) -> ToolingTypeMappings {
  guard let overrides else {
    return makeDefaultToolingTypeMappings()
  }

  var merged = makeDefaultToolingTypeMappings().coreDataTypes
  for (key, rule) in overrides.coreDataTypes {
    merged[key] = rule
  }
  return .init(coreDataTypes: merged)
}
