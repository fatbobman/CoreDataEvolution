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

/// Shared enums used by config templates, requests, and future IR/generation layers.
public enum ToolingAccessLevel: String, Codable, Sendable, Equatable {
  case `internal`
  case `public`
}

public enum ToolingOverwriteMode: String, Codable, Sendable, Equatable {
  case none
  case changed
  case all
}

public enum ToolingFormatMode: String, Codable, Sendable, Equatable {
  case none
  case swiftFormat = "swift-format"
  case swiftformat
}

public enum ToolingRelationshipGenerationPolicy: String, Codable, Sendable, Equatable {
  case none
  case warning
  case plain
}

public enum ToolingDecodeFailurePolicy: String, Codable, Sendable, Equatable {
  case fallbackToDefaultValue
  case debugAssertNil
}

public enum ToolingValidationLevel: String, Codable, Sendable, Equatable {
  case quick
  case strict
}

public enum ToolingReportFormat: String, Codable, Sendable, Equatable {
  case text
  case json
  case sarif
}
