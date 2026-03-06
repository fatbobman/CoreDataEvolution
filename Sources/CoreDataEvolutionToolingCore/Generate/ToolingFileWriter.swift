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

/// Applies overwrite and stale-cleanup policies to planned generated files.
///
/// The writer only deletes files that still carry the stable managed marker and only inside the
/// requested output directory.
public enum ToolingFileWriter {
  public static func apply(
    plan: [ToolingGeneratedFilePlan],
    outputDir: String,
    overwrite: ToolingOverwriteMode,
    cleanStale: Bool,
    dryRun: Bool,
    fileManager: FileManager = .default
  ) throws -> ToolingGeneratedWriteResult {
    let planByOutputPath = Dictionary(
      uniqueKeysWithValues: plan.map { (normalizePath($0.outputPath), $0) }
    )
    let plannedOutputPaths = Set(planByOutputPath.keys)
    var operations: [ToolingGeneratedFileOperation] = []
    let outputDirectoryURL = URL(fileURLWithPath: outputDir, isDirectory: true)
      .resolvingSymlinksInPath()

    if dryRun == false {
      try fileManager.createDirectory(
        at: outputDirectoryURL,
        withIntermediateDirectories: true
      )
    }

    for file in plan {
      let outputURL = URL(fileURLWithPath: file.outputPath)
      let existingContents = try readExistingContentsIfPresent(
        at: outputURL, fileManager: fileManager)
      let operation = try decideOperation(
        for: file,
        existingContents: existingContents,
        overwrite: overwrite,
        fileManager: fileManager
      )
      operations.append(operation)

      guard dryRun == false else { continue }
      switch operation.kind {
      case .create, .update:
        try fileManager.createDirectory(
          at: outputURL.deletingLastPathComponent(),
          withIntermediateDirectories: true
        )
        try file.contents.write(to: outputURL, atomically: true, encoding: .utf8)
      case .unchanged, .skipExisting, .delete:
        break
      }
    }

    if cleanStale {
      let staleFiles = try findStaleManagedFiles(
        in: outputDirectoryURL,
        plannedOutputPaths: plannedOutputPaths,
        fileManager: fileManager
      )

      for staleFileURL in staleFiles.sorted(by: { $0.path < $1.path }) {
        let normalizedStalePath = normalizePath(staleFileURL.path)
        let relativePath = normalizedStalePath.replacingOccurrences(
          of: normalizePath(outputDirectoryURL.path) + "/",
          with: ""
        )
        operations.append(
          .init(
            kind: .delete,
            relativePath: relativePath,
            outputPath: staleFileURL.path
          )
        )

        if dryRun == false {
          try fileManager.removeItem(at: staleFileURL)
        }
      }
    }

    return .init(dryRun: dryRun, operations: operations)
  }

  private static func readExistingContentsIfPresent(
    at url: URL,
    fileManager: FileManager
  ) throws -> String? {
    guard fileManager.fileExists(atPath: url.path) else { return nil }

    do {
      return try String(contentsOf: url, encoding: .utf8)
    } catch {
      throw ToolingFailure.runtime(
        .ioFailed,
        "failed to read existing generated file at '\(url.path)' (\(error.localizedDescription))."
      )
    }
  }

  private static func decideOperation(
    for plan: ToolingGeneratedFilePlan,
    existingContents: String?,
    overwrite: ToolingOverwriteMode,
    fileManager: FileManager
  ) throws -> ToolingGeneratedFileOperation {
    guard let existingContents else {
      return .init(kind: .create, relativePath: plan.relativePath, outputPath: plan.outputPath)
    }

    if existingContents == plan.contents {
      return .init(kind: .unchanged, relativePath: plan.relativePath, outputPath: plan.outputPath)
    }

    switch overwrite {
    case .none:
      throw ToolingFailure.user(
        .writeDenied,
        "target file already exists at '\(plan.outputPath)'. Use overwrite=changed/all to continue."
      )
    case .changed:
      guard existingContents.contains(toolingManagedFileMarker) else {
        throw ToolingFailure.user(
          .writeDenied,
          "refusing to overwrite non-generated file at '\(plan.outputPath)' in overwrite=changed mode."
        )
      }
      return .init(kind: .update, relativePath: plan.relativePath, outputPath: plan.outputPath)
    case .all:
      return .init(kind: .update, relativePath: plan.relativePath, outputPath: plan.outputPath)
    }
  }

  private static func findStaleManagedFiles(
    in outputDirectoryURL: URL,
    plannedOutputPaths: Set<String>,
    fileManager: FileManager
  ) throws -> [URL] {
    guard fileManager.fileExists(atPath: outputDirectoryURL.path) else { return [] }

    guard
      let enumerator = fileManager.enumerator(
        at: outputDirectoryURL,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
      )
    else {
      return []
    }

    var staleFiles: [URL] = []
    for case let fileURL as URL in enumerator {
      let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
      guard resourceValues.isRegularFile == true else { continue }
      guard plannedOutputPaths.contains(normalizePath(fileURL.path)) == false else { continue }

      let contents = try readExistingContentsIfPresent(at: fileURL, fileManager: fileManager)
      if contents?.contains(toolingManagedFileMarker) == true {
        staleFiles.append(fileURL)
      }
    }

    return staleFiles
  }

  private static func normalizePath(_ path: String) -> String {
    URL(fileURLWithPath: path).resolvingSymlinksInPath().path
  }
}
