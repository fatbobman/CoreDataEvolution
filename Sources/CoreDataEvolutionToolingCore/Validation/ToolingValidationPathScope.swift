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

/// Shared include/exclude path matching used by validate source parsing and strict file drift
/// detection.
struct ToolingValidationPathScope {
  let includeMatchers: [ToolingGlobMatcher]
  let excludeMatchers: [ToolingGlobMatcher]

  init(include: [String], exclude: [String]) {
    includeMatchers = include.map(ToolingGlobMatcher.init)
    excludeMatchers = exclude.map(ToolingGlobMatcher.init)
  }

  func contains(_ relativePath: String) -> Bool {
    if includeMatchers.isEmpty == false
      && includeMatchers.contains(where: { $0.matches(relativePath) }) == false
    {
      return false
    }

    if excludeMatchers.contains(where: { $0.matches(relativePath) }) {
      return false
    }

    return true
  }
}

struct ToolingGlobMatcher {
  private let regex: NSRegularExpression

  init(_ pattern: String) {
    let escaped = NSRegularExpression.escapedPattern(for: pattern)
      .replacingOccurrences(of: #"\*"#, with: ".*")
      .replacingOccurrences(of: #"\?"#, with: ".")
    self.regex = try! NSRegularExpression(pattern: "^\(escaped)$")
  }

  func matches(_ text: String) -> Bool {
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    return regex.firstMatch(in: text, range: range) != nil
  }
}
