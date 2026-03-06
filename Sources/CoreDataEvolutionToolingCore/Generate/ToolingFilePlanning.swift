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

/// Converts rendered source units into concrete output files under `outputDir`.
///
/// This layer also injects the stable managed-file marker that later overwrite and stale cleanup
/// logic relies on.
public enum ToolingFilePlanner {
  public static func makeFilePlan(
    from sources: [ToolingGeneratedSource],
    outputDir: String
  ) throws -> [ToolingGeneratedFilePlan] {
    let outputDirectoryURL = URL(fileURLWithPath: outputDir, isDirectory: true)
    var plannedRelativePaths = Set<String>()

    return try sources.map { source in
      let relativePath = source.suggestedFileName
      guard plannedRelativePaths.insert(relativePath).inserted else {
        throw ToolingFailure.user(
          .configInvalid,
          "generate produced duplicate output file name '\(relativePath)'."
        )
      }

      let outputURL = outputDirectoryURL.appendingPathComponent(relativePath)
      return .init(
        relativePath: relativePath,
        outputPath: outputURL.path,
        management: source.management,
        contents: source.management == .managed
          ? makeManagedContents(from: source.contents)
          : source.contents
      )
    }
  }

  /// Injects the stable management header after any leading header comments.
  ///
  /// This keeps custom copyright headers at the top while still allowing later file detection to
  /// distinguish tooling-managed files from hand-written sources.
  public static func makeManagedContents(from contents: String) -> String {
    let normalizedContents = contents.hasSuffix("\n") ? contents : contents + "\n"
    var lines = normalizedContents.split(separator: "\n", omittingEmptySubsequences: false)

    var insertionIndex = 0
    while insertionIndex < lines.count {
      let trimmed = lines[insertionIndex].trimmingCharacters(in: .whitespaces)
      if trimmed.isEmpty || trimmed.hasPrefix("//") {
        insertionIndex += 1
      } else {
        break
      }
    }

    let headerLines = toolingManagedFileHeader.split(
      separator: "\n", omittingEmptySubsequences: false)
    for (offset, headerLine) in headerLines.enumerated() {
      lines.insert(headerLine, at: insertionIndex + offset)
    }
    lines.insert(Substring(""), at: insertionIndex + headerLines.count)
    return lines.joined(separator: "\n")
  }
}
