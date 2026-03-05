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

func failUser(code: ToolingErrorCode, message: String, hint: String? = nil) throws -> Never {
  emitError(code: code, message: message, hint: hint)
  throw ExitCode(1)
}

func failInternal(code: ToolingErrorCode, message: String, hint: String? = nil) throws -> Never {
  emitError(code: code, message: message, hint: hint)
  throw ExitCode(2)
}

func emitError(code: ToolingErrorCode, message: String, hint: String?) {
  fputs("error[\(code.rawValue)]: \(message)\n", stderr)
  if let hint {
    fputs("hint: \(hint)\n", stderr)
  }
}
