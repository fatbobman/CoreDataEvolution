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

/// Stable marker injected into generated files so overwrite and stale cleanup only touch files
/// managed by the tooling pipeline.
public let toolingManagedFileMarker = "// cde-tool:generated"

/// Human-readable managed-file header inserted into every generated Swift file.
///
/// The first line is the stable machine-readable marker used by validate/write logic. The
/// following lines are intentionally static guidance for developers and avoid timestamps or other
/// changing metadata that would introduce noisy diffs.
public let toolingManagedFileHeader = """
  // cde-tool:generated
  // Do not edit by hand.
  // Regenerate with cde-tool generate.
  """

/// One planned output file derived from rendered Swift sources.
///
/// The file plan is the boundary between source rendering and disk writes. It carries fully
/// materialized file contents plus the concrete output path inside `outputDir`.
public struct ToolingGeneratedFilePlan: Codable, Sendable, Equatable {
  public let relativePath: String
  public let outputPath: String
  public let management: ToolingGeneratedFileManagement
  public let contents: String

  public init(
    relativePath: String,
    outputPath: String,
    management: ToolingGeneratedFileManagement = .managed,
    contents: String
  ) {
    self.relativePath = relativePath
    self.outputPath = outputPath
    self.management = management
    self.contents = contents
  }
}

/// Summarizes how one planned file or stale file was handled by the writer.
public enum ToolingGeneratedFileOperationKind: String, Codable, Sendable, Equatable {
  case create
  case update
  case unchanged
  case skipExisting
  case delete
}

/// Concrete create/update/delete decision produced by the writer layer.
public struct ToolingGeneratedFileOperation: Codable, Sendable, Equatable {
  public let kind: ToolingGeneratedFileOperationKind
  public let relativePath: String
  public let outputPath: String

  public init(
    kind: ToolingGeneratedFileOperationKind,
    relativePath: String,
    outputPath: String
  ) {
    self.kind = kind
    self.relativePath = relativePath
    self.outputPath = outputPath
  }
}

/// Final write summary returned by `GenerateService`.
///
/// `dryRun` uses the same operation model as real writes so CLI and future GUI surfaces can show
/// the exact file diff summary without touching disk.
public struct ToolingGeneratedWriteResult: Codable, Sendable, Equatable {
  public let dryRun: Bool
  public let operations: [ToolingGeneratedFileOperation]

  public init(
    dryRun: Bool,
    operations: [ToolingGeneratedFileOperation]
  ) {
    self.dryRun = dryRun
    self.operations = operations
  }
}
