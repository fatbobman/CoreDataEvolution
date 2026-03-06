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

import CoreDataEvolutionToolingCore
import Foundation

/// Builds runtime generate requests from CLI inputs and optionally executes the requested
/// formatter after files are written.
enum GenerateCommandSupport {
  static func makeRequest(from command: GenerateCommand) throws -> GenerateRequest {
    if let config = command.config {
      let configURL = makeAbsoluteURL(fromCLIPath: config)
      let template = try loadToolingConfigTemplate(at: configURL)
      guard let generate = template.generate else {
        throw ToolingFailure.user(
          .configInvalid,
          "config file does not contain a generate section."
        )
      }

      var overrides = GenerateRequestOverrides()
      overrides.modelPath = command.modelPath
      overrides.modelVersion = command.modelVersion
      overrides.momcBin = command.momcBin
      overrides.outputDir = command.outputDir
      overrides.moduleName = command.moduleName
      overrides.accessLevel = command.accessLevel
      overrides.singleFile = command.singleFile
      overrides.splitByEntity = command.splitByEntity
      overrides.overwrite = command.overwrite
      overrides.cleanStale = command.cleanStale
      overrides.dryRun = command.dryRun
      overrides.format = command.format
      overrides.emitExtensionStubs = command.emitExtensionStubs
      overrides.generateInit = command.generateInit
      overrides.relationshipSetterPolicy = command.relationshipSetterPolicy
      overrides.relationshipCountPolicy = command.relationshipCountPolicy
      overrides.defaultDecodeFailurePolicy = command.defaultDecodeFailurePolicy
      overrides.headerTemplate = command.headerTemplate.map {
        makeAbsoluteURL(fromCLIPath: $0).path
      }

      return try GenerateRequest(
        config: generate,
        overrides: overrides,
        configDirectory: configURL.deletingLastPathComponent()
      )
    }

    guard let modelPath = command.modelPath else {
      throw ToolingFailure.user(
        .configInvalid, "--model-path is required when --config is not used.")
    }
    guard let outputDir = command.outputDir else {
      throw ToolingFailure.user(
        .configInvalid, "--output-dir is required when --config is not used.")
    }
    guard let moduleName = command.moduleName else {
      throw ToolingFailure.user(
        .configInvalid, "--module-name is required when --config is not used.")
    }

    let template = GenerateTemplate(
      modelPath: makeAbsoluteURL(fromCLIPath: modelPath).path,
      modelVersion: command.modelVersion,
      momcBin: command.momcBin.map { makeAbsoluteURL(fromCLIPath: $0).path },
      outputDir: makeAbsoluteURL(fromCLIPath: outputDir).path,
      moduleName: moduleName,
      typeMappings: nil,
      attributeRules: nil,
      accessLevel: command.accessLevel,
      singleFile: command.singleFile,
      splitByEntity: command.splitByEntity,
      overwrite: command.overwrite,
      cleanStale: command.cleanStale,
      dryRun: command.dryRun,
      format: command.format,
      headerTemplate: command.headerTemplate.map { makeAbsoluteURL(fromCLIPath: $0).path },
      emitExtensionStubs: command.emitExtensionStubs,
      generateInit: command.generateInit,
      relationshipSetterPolicy: command.relationshipSetterPolicy,
      relationshipCountPolicy: command.relationshipCountPolicy,
      defaultDecodeFailurePolicy: command.defaultDecodeFailurePolicy
    )

    return try GenerateRequest(config: template)
  }

  static func emitResult(_ result: GenerateResult) {
    for diagnostic in result.diagnostics {
      emitDiagnostic(diagnostic)
    }

    for operation in result.writeResult.operations {
      let verb: String
      switch operation.kind {
      case .create:
        verb = result.writeResult.dryRun ? "would create" : "created"
      case .update:
        verb = result.writeResult.dryRun ? "would update" : "updated"
      case .unchanged:
        verb = "unchanged"
      case .skipExisting:
        verb = result.writeResult.dryRun ? "would skip" : "skipped"
      case .delete:
        verb = result.writeResult.dryRun ? "would delete" : "deleted"
      }
      print("\(verb): \(operation.relativePath)")
    }
  }

  static func runFormatterIfNeeded(
    mode: ToolingFormatMode,
    result: GenerateResult
  ) throws {
    guard mode != .none else { return }
    guard result.writeResult.dryRun == false else { return }

    let targetPaths = result.writeResult.operations.compactMap { operation -> String? in
      switch operation.kind {
      case .create, .update:
        return operation.outputPath
      case .unchanged, .skipExisting, .delete:
        return nil
      }
    }

    guard targetPaths.isEmpty == false else { return }

    let executable: String
    var arguments: [String]
    switch mode {
    case .none:
      return
    case .swiftFormat:
      executable = "swift-format"
      arguments = ["format", "--in-place"] + targetPaths
    case .swiftformat:
      executable = "swiftformat"
      arguments = targetPaths
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = [executable] + arguments

    let stderrPipe = Pipe()
    process.standardError = stderrPipe

    do {
      try process.run()
      process.waitUntilExit()
    } catch {
      throw ToolingFailure.runtime(
        .ioFailed,
        "failed to launch formatter '\(executable)' (\(error.localizedDescription))."
      )
    }

    guard process.terminationStatus == 0 else {
      let data = stderrPipe.fileHandleForReading.readDataToEndOfFile()
      let stderrText = String(data: data, encoding: .utf8)?.trimmingCharacters(
        in: .whitespacesAndNewlines
      )
      throw ToolingFailure.user(
        .ioFailed,
        "formatter '\(executable)' failed.",
        hint: stderrText?.isEmpty == false ? stderrText : nil
      )
    }
  }

  private static func emitDiagnostic(_ diagnostic: ToolingDiagnostic) {
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
  }

  private static func makeAbsoluteURL(fromCLIPath path: String) -> URL {
    if (path as NSString).isAbsolutePath {
      return URL(fileURLWithPath: path)
    }
    return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
      .appendingPathComponent(path)
  }
}
