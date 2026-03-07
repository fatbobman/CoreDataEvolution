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

/// Severity model shared by CLI text output and future structured reports.
public enum ToolingDiagnosticSeverity: String, Codable, Sendable {
  case error
  case warning
  case note
}

/// A UTF-8 text range inside one source file.
public struct ToolingTextRange: Codable, Sendable, Equatable {
  public let startUTF8Offset: Int
  public let endUTF8Offset: Int

  public init(
    startUTF8Offset: Int,
    endUTF8Offset: Int
  ) {
    self.startUTF8Offset = startUTF8Offset
    self.endUTF8Offset = endUTF8Offset
  }
}

/// One deterministic text edit that tooling can safely apply to source.
public struct ToolingTextEdit: Codable, Sendable, Equatable {
  public let filePath: String
  public let range: ToolingTextRange
  public let replacement: String

  public init(
    filePath: String,
    range: ToolingTextRange,
    replacement: String
  ) {
    self.filePath = filePath
    self.range = range
    self.replacement = replacement
  }
}

/// A concrete source change suggestion attached to one diagnostic.
public struct ToolingFixSuggestion: Codable, Sendable, Equatable {
  public let summary: String
  public let isSafeAutofix: Bool
  public let edits: [ToolingTextEdit]

  public init(
    summary: String,
    isSafeAutofix: Bool,
    edits: [ToolingTextEdit]
  ) {
    self.summary = summary
    self.isSafeAutofix = isSafeAutofix
    self.edits = edits
  }
}

/// A non-fatal issue emitted by tooling services.
public struct ToolingDiagnostic: Codable, Sendable, Equatable {
  public let severity: ToolingDiagnosticSeverity
  public let code: ToolingErrorCode?
  public let message: String
  public let hint: String?
  public let fix: ToolingFixSuggestion?

  public init(
    severity: ToolingDiagnosticSeverity,
    code: ToolingErrorCode?,
    message: String,
    hint: String? = nil,
    fix: ToolingFixSuggestion? = nil
  ) {
    self.severity = severity
    self.code = code
    self.message = message
    self.hint = hint
    self.fix = fix
  }
}

/// A fatal tooling error that already carries an exit-code classification.
public struct ToolingFailure: Error, Sendable, Equatable {
  public let code: ToolingErrorCode
  public let message: String
  public let hint: String?
  public let exitCode: Int32

  public init(
    code: ToolingErrorCode,
    message: String,
    hint: String? = nil,
    exitCode: Int32
  ) {
    self.code = code
    self.message = message
    self.hint = hint
    self.exitCode = exitCode
  }

  public static func user(
    _ code: ToolingErrorCode,
    _ message: String,
    hint: String? = nil
  ) -> ToolingFailure {
    .init(code: code, message: message, hint: hint, exitCode: 1)
  }

  public static func runtime(
    _ code: ToolingErrorCode,
    _ message: String,
    hint: String? = nil
  ) -> ToolingFailure {
    .init(code: code, message: message, hint: hint, exitCode: 2)
  }
}
