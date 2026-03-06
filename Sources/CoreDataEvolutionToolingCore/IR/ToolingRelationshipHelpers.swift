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

/// Shared relationship helpers used by tooling generation and validation.
///
/// These helpers keep ambiguity detection and simple entity-name matching consistent across
/// generate/validate paths.
func toolingAmbiguousRelationshipNames(in entity: ToolingEntityIR) -> Set<String> {
  let grouped = Dictionary(grouping: entity.relationships) {
    $0.destinationEntityName ?? "<missing>"
  }
  return Set(
    grouped.values
      .filter { $0.count > 1 }
      .flatMap { $0.map(\.swiftName) }
  )
}

func toolingTypeNamesReferToSameEntity(_ lhs: String, _ rhs: String) -> Bool {
  if lhs == rhs {
    return true
  }
  return lhs.split(separator: ".").last == rhs.split(separator: ".").last
}
