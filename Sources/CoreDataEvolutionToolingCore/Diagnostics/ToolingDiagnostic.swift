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

/// A non-fatal issue emitted by tooling services.
public struct ToolingDiagnostic: Codable, Sendable, Equatable {
  public let severity: ToolingDiagnosticSeverity
  public let code: ToolingErrorCode?
  public let message: String
  public let hint: String?

  public init(
    severity: ToolingDiagnosticSeverity,
    code: ToolingErrorCode?,
    message: String,
    hint: String? = nil
  ) {
    self.severity = severity
    self.code = code
    self.message = message
    self.hint = hint
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
