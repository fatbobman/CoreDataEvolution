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

public enum ToolingErrorCode: String, Sendable {
  case notImplemented = "CLI-NOT-IMPLEMENTED"
  case configConflict = "CLI-CONFIG-CONFLICT"
  case configExists = "CLI-CONFIG-EXISTS"
  case configSchemaUnsupported = "CLI-CONFIG-SCHEMA-UNSUPPORTED"
  case jsonEncodeFailed = "CLI-JSON-ENCODE-FAILED"
  case outputDirMissing = "CLI-OUTPUT-DIR-MISSING"
  case writeDenied = "CLI-WRITE-DENIED"
}
