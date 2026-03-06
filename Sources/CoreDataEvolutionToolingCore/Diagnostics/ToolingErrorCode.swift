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

/// Stable error identifiers shared across CLI, future plugin adapters, and GUI surfaces.
///
/// Keep raw values stable once they are consumed externally.
public enum ToolingErrorCode: String, Codable, Sendable {
  case notImplemented = "TOOL-NOT-IMPLEMENTED"
  case configConflict = "TOOL-CONFIG-CONFLICT"
  case configExists = "TOOL-CONFIG-EXISTS"
  case configSchemaUnsupported = "TOOL-CONFIG-SCHEMA-UNSUPPORTED"
  case ioFailed = "TOOL-IO-FAILED"
  case internalError = "TOOL-INTERNAL"
  case jsonEncodeFailed = "TOOL-JSON-ENCODE-FAILED"
  case modelCompileFailed = "TOOL-MODEL-COMPILE-FAILED"
  case modelLoadFailed = "TOOL-MODEL-LOAD-FAILED"
  case modelNotFound = "TOOL-MODEL-NOT-FOUND"
  case modelUnsupported = "TOOL-MODEL-UNSUPPORTED"
  case modelVersionNotFound = "TOOL-MODEL-VERSION-NOT-FOUND"
  case momcNotFound = "TOOL-MOMC-NOT-FOUND"
  case outputDirMissing = "TOOL-OUTPUT-DIR-MISSING"
  case writeDenied = "TOOL-WRITE-DENIED"
}
