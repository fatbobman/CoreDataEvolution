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

/// Build metadata used by `cde-tool --version`, `cde-tool -v`, and release scripts.
enum ToolVersionInfo {
  static var version: String {
    ToolBuildMetadata.version
  }

  static var detailedDescription: String {
    """
    cde-tool \(ToolBuildMetadata.version)
    CoreDataEvolution tag: \(ToolBuildMetadata.gitTag)
    commit: \(ToolBuildMetadata.gitCommit)
    describe: \(ToolBuildMetadata.gitDescribe)
    dirty: \(ToolBuildMetadata.isDirty ? "true" : "false")
    """
  }
}
