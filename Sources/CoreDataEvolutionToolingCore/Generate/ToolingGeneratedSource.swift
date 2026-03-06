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

/// One generated Swift source unit produced by the tooling generate engine.
///
/// Session 4 stops at in-memory source generation. Session 5 will wrap these units into file
/// plans, overwrite decisions, and on-disk writes.
public struct ToolingGeneratedSource: Codable, Sendable, Equatable {
  public let entityName: String
  public let suggestedFileName: String
  public let contents: String

  public init(
    entityName: String,
    suggestedFileName: String,
    contents: String
  ) {
    self.entityName = entityName
    self.suggestedFileName = suggestedFileName
    self.contents = contents
  }
}
