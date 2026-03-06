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

/// One rendered Swift source unit produced before file planning.
///
/// Session 5 converts these units into concrete file plans and on-disk write operations.
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
