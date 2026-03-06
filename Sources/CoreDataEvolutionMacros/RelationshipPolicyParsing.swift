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

/// Shared parser for relationship generation policies accepted by both `@PersistentModel` and the
/// internal `@_CDRelationship` macro.
func parseRelationshipGenerationPolicy(
  from raw: String
) -> ParsedRelationshipGenerationPolicy? {
  switch raw {
  case ".none", "RelationshipGenerationPolicy.none",
    "CoreDataEvolution.RelationshipGenerationPolicy.none":
    return ParsedRelationshipGenerationPolicy.none
  case ".warning", "RelationshipGenerationPolicy.warning",
    "CoreDataEvolution.RelationshipGenerationPolicy.warning":
    return ParsedRelationshipGenerationPolicy.warning
  case ".plain", "RelationshipGenerationPolicy.plain",
    "CoreDataEvolution.RelationshipGenerationPolicy.plain":
    return ParsedRelationshipGenerationPolicy.plain
  default:
    return nil
  }
}
