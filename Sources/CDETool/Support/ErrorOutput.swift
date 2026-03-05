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
import Foundation

func failUser(code: String, message: String, hint: String? = nil) throws -> Never {
  emitError(code: code, message: message, hint: hint)
  throw ExitCode(1)
}

func failInternal(code: String, message: String, hint: String? = nil) throws -> Never {
  emitError(code: code, message: message, hint: hint)
  throw ExitCode(2)
}

func emitError(code: String, message: String, hint: String?) {
  fputs("error[\(code)]: \(message)\n", stderr)
  if let hint {
    fputs("hint: \(hint)\n", stderr)
  }
}
