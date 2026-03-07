//
//  ------------------------------------------------
//  Original project: CoreDataEvolution
//  Created on 2026/3/7 by Fatbobman(东坡肘子)
//  X: @fatbobman
//  Mastodon: @fatbobman@mastodon.social
//  GitHub: @fatbobman
//  Blog: https://fatbobman.com
//  ------------------------------------------------
//  Copyright © 2024-present Fatbobman. All rights reserved.

import Foundation

/// Applies deterministic, model-derived source fixes emitted by validate diagnostics.
///
/// The applier intentionally stays conservative:
/// - only `diagnostic.fix?.isSafeAutofix == true` is considered
/// - conflicting or overlapping edits fail instead of guessing an order
/// - edits operate on UTF-8 offsets captured from the parsed source
public enum ToolingFixApplier {
  public static func applySafeFixes(
    from diagnostics: [ToolingDiagnostic],
    dryRun: Bool,
    fileManager: FileManager = .default
  ) throws -> ToolingFixApplyResult {
    let rawEdits = diagnostics.compactMap(\.fix)
      .filter(\.isSafeAutofix)
      .flatMap(\.edits)
    let edits = deduplicated(rawEdits)
    guard edits.isEmpty == false else {
      return .init(appliedFixCount: 0, appliedEditCount: 0, touchedFiles: [])
    }

    let editsByFile = Dictionary(grouping: edits, by: \.filePath)
    for (filePath, fileEdits) in editsByFile {
      try validateNonOverlappingEdits(fileEdits, filePath: filePath)
      if dryRun {
        continue
      }
      try apply(fileEdits, to: filePath, fileManager: fileManager)
    }

    return .init(
      appliedFixCount: diagnostics.compactMap(\.fix).filter(\.isSafeAutofix).count,
      appliedEditCount: edits.count,
      touchedFiles: editsByFile.keys.sorted()
    )
  }

  private static func deduplicated(_ edits: [ToolingTextEdit]) -> [ToolingTextEdit] {
    var unique: [ToolingTextEdit] = []
    var seen = Set<String>()
    for edit in edits {
      let key =
        "\(edit.filePath)#\(edit.range.startUTF8Offset)#\(edit.range.endUTF8Offset)#\(edit.replacement)"
      if seen.insert(key).inserted {
        unique.append(edit)
      }
    }
    return unique
  }

  private static func validateNonOverlappingEdits(
    _ edits: [ToolingTextEdit],
    filePath: String
  ) throws {
    let sorted = edits.sorted {
      if $0.range.startUTF8Offset == $1.range.startUTF8Offset {
        return $0.range.endUTF8Offset < $1.range.endUTF8Offset
      }
      return $0.range.startUTF8Offset < $1.range.startUTF8Offset
    }

    for index in 1..<sorted.count {
      let previous = sorted[index - 1]
      let current = sorted[index]
      if current.range.startUTF8Offset < previous.range.endUTF8Offset {
        throw ToolingFailure.user(
          .validationFailed,
          "validate produced overlapping autofix edits for '\(filePath)'."
        )
      }
    }
  }

  private static func apply(
    _ edits: [ToolingTextEdit],
    to filePath: String,
    fileManager: FileManager
  ) throws {
    guard fileManager.fileExists(atPath: filePath) else {
      throw ToolingFailure.user(
        .validationFailed,
        "validate could not apply autofix because source file is missing: '\(filePath)'."
      )
    }

    var data = try Data(contentsOf: URL(fileURLWithPath: filePath))
    for edit in edits.sorted(by: { $0.range.startUTF8Offset > $1.range.startUTF8Offset }) {
      guard edit.range.endUTF8Offset <= data.count else {
        throw ToolingFailure.runtime(
          .internalError,
          "validate produced an out-of-bounds autofix edit for '\(filePath)'."
        )
      }
      let replacementData = Data(edit.replacement.utf8)
      data.replaceSubrange(
        edit.range.startUTF8Offset..<edit.range.endUTF8Offset,
        with: replacementData
      )
    }

    try data.write(to: URL(fileURLWithPath: filePath))
  }
}

public struct ToolingFixApplyResult: Sendable, Equatable {
  public let appliedFixCount: Int
  public let appliedEditCount: Int
  public let touchedFiles: [String]

  public init(
    appliedFixCount: Int,
    appliedEditCount: Int,
    touchedFiles: [String]
  ) {
    self.appliedFixCount = appliedFixCount
    self.appliedEditCount = appliedEditCount
    self.touchedFiles = touchedFiles
  }
}
