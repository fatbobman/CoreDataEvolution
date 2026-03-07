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

/// Default metadata for source builds.
///
/// `Scripts/build-cde-tool.sh` temporarily rewrites this file before release builds so the produced
/// binary carries tag/commit information without leaving the workspace dirty afterwards.
enum ToolBuildMetadata {
  static let version = "0.0.0-dev"
  static let gitTag = "unreleased"
  static let gitCommit = "unknown"
  static let gitDescribe = "unreleased"
  static let isDirty = true
}
