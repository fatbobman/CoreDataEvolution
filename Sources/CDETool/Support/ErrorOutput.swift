//
//  ------------------------------------------------
//  Original project: CoreDataEvolution
//  Created on 2026/3/5 by Fatbobman(东坡肘子)
//  X: @fatbobman
//  Mastodon: @fatbobman@mastodon.social
//  GitHub: @fatbobman
//  Blog: https://fatbobman.com
//  ------------------------------------------------
//  Copyright © 2024-present Fatbobman. All rights reserved.

import ArgumentParser
import CoreDataEvolutionToolingCore
import Foundation

func emitInfo(_ message: String) {
  print(message)
}

func emitInfoToErrorStream(_ message: String) {
  fputs("\(message)\n", stderr)
}

func emitWriteSuccess(kind: String, path: String) {
  emitInfo("wrote \(kind) to \(path)")
}

func failUser(code: ToolingErrorCode, message: String, hint: String? = nil) throws -> Never {
  emitError(code: code, message: message, hint: hint)
  throw ExitCode(1)
}

func failInternal(code: ToolingErrorCode, message: String, hint: String? = nil) throws -> Never {
  emitError(code: code, message: message, hint: hint)
  throw ExitCode(2)
}

func fail(_ failure: ToolingFailure) throws -> Never {
  emitError(code: failure.code, message: failure.message, hint: failure.hint)
  throw ExitCode(failure.exitCode)
}

func emitError(code: ToolingErrorCode, message: String, hint: String?) {
  fputs("error[\(code.rawValue)]: \(message)\n", stderr)
  if let hint {
    fputs("hint: \(hint)\n", stderr)
  }
}

func emitDiagnostic(_ diagnostic: ToolingDiagnostic) {
  let label: String
  switch diagnostic.severity {
  case .error:
    label = "error"
  case .warning:
    label = "warning"
  case .note:
    label = "note"
  }

  let code = diagnostic.code.map(\.rawValue)
  let prefix = code.map { "\(label)[\($0)]" } ?? label
  fputs("\(prefix): \(diagnostic.message)\n", stderr)
  if let hint = diagnostic.hint {
    fputs("hint: \(hint)\n", stderr)
  }
  if let fix = diagnostic.fix {
    let mode = fix.isSafeAutofix ? "safe autofix" : "suggested fix"
    fputs("\(mode): \(fix.summary)\n", stderr)
  }
}
