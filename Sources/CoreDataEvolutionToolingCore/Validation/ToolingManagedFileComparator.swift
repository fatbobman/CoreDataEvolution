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

/// Performs strict drift checks against tool-managed files on disk.
///
/// Strict validation only compares files carrying the stable generated marker. Hand-written files
/// without the marker are ignored even when they live under the same source directory.
enum ToolingManagedFileComparator {
  static func compareStrict(
    expected plan: [ToolingGeneratedFilePlan],
    sourceDirectory: String,
    include: [String],
    exclude: [String],
    fileManager: FileManager = .default
  ) throws -> [ToolingDiagnostic] {
    let sourceDirectoryURL = URL(fileURLWithPath: sourceDirectory, isDirectory: true)
      .resolvingSymlinksInPath()
    let pathScope = ToolingValidationPathScope(include: include, exclude: exclude)
    let expectedByRelativePath = Dictionary(
      uniqueKeysWithValues:
        plan
        .filter { pathScope.contains($0.relativePath) }
        .map { ($0.relativePath, $0) }
    )
    let actualManagedFiles = try findManagedFiles(
      in: sourceDirectoryURL,
      pathScope: pathScope,
      fileManager: fileManager
    )

    var diagnostics: [ToolingDiagnostic] = []

    for (relativePath, expectedFile) in expectedByRelativePath.sorted(by: { $0.key < $1.key }) {
      guard let actualContents = actualManagedFiles[relativePath] else {
        let outputURL = sourceDirectoryURL.appendingPathComponent(relativePath)
        if fileManager.fileExists(atPath: outputURL.path) {
          diagnostics.append(
            error(
              "validate strict expected managed file '\(relativePath)' but found a non-managed file at the same path."
            )
          )
        } else {
          diagnostics.append(
            error(
              "validate strict could not find managed file '\(relativePath)'."
            )
          )
        }
        continue
      }

      if actualContents != expectedFile.contents {
        diagnostics.append(
          error(
            "validate strict found content drift in managed file '\(relativePath)'."
          )
        )
      }
    }

    for relativePath in actualManagedFiles.keys.sorted()
    where expectedByRelativePath[relativePath] == nil {
      diagnostics.append(
        error(
          "validate strict found stale managed file '\(relativePath)' not produced by current rules."
        )
      )
    }

    return diagnostics
  }

  private static func findManagedFiles(
    in sourceDirectoryURL: URL,
    pathScope: ToolingValidationPathScope,
    fileManager: FileManager
  ) throws -> [String: String] {
    guard fileManager.fileExists(atPath: sourceDirectoryURL.path) else { return [:] }
    guard
      let enumerator = fileManager.enumerator(
        at: sourceDirectoryURL,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
      )
    else {
      return [:]
    }

    var files: [String: String] = [:]
    for case let fileURL as URL in enumerator {
      let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
      guard resourceValues.isRegularFile == true else { continue }
      guard fileURL.pathExtension == "swift" else { continue }

      let normalizedFilePath = fileURL.resolvingSymlinksInPath().path
      let relativePath = normalizedFilePath.replacingOccurrences(
        of: sourceDirectoryURL.path + "/",
        with: ""
      )
      guard pathScope.contains(relativePath) else { continue }

      let contents = try String(contentsOf: fileURL, encoding: .utf8)
      if contents.contains(toolingManagedFileMarker) {
        files[relativePath] = contents
      }
    }

    return files
  }

  private static func error(_ message: String) -> ToolingDiagnostic {
    .init(severity: .error, code: .validationFailed, message: message)
  }
}
