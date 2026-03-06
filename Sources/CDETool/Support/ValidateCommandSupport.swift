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

/// Builds runtime validate requests from CLI inputs and renders validate reports.
enum ValidateCommandSupport {
  static func makeRequest(from command: ValidateCommand) throws -> ValidateRequest {
    if let config = command.config {
      let configURL = makeAbsoluteURL(fromCLIPath: config)
      let template = try loadToolingConfigTemplate(at: configURL)
      guard let validate = template.validate else {
        throw ToolingFailure.user(
          .configInvalid,
          "config file does not contain a validate section."
        )
      }

      var overrides = ValidateRequestOverrides()
      overrides.modelPath = command.modelPath
      overrides.modelVersion = command.modelVersion
      overrides.momcBin = command.momcBin
      overrides.sourceDir = command.sourceDir
      overrides.moduleName = command.moduleName
      overrides.accessLevel = command.accessLevel
      overrides.singleFile = command.singleFile
      overrides.splitByEntity = command.splitByEntity
      overrides.headerTemplate = command.headerTemplate.map {
        makeAbsoluteURL(fromCLIPath: $0).path
      }
      overrides.generateInit = command.generateInit
      overrides.relationshipSetterPolicy = command.relationshipSetterPolicy
      overrides.relationshipCountPolicy = command.relationshipCountPolicy
      overrides.defaultDecodeFailurePolicy = command.defaultDecodeFailurePolicy
      overrides.include = splitCSVPatterns(command.include)
      overrides.exclude = splitCSVPatterns(command.exclude)
      overrides.level = command.level
      overrides.report = command.report
      overrides.failOnWarning = command.failOnWarning
      overrides.maxIssues = command.maxIssues

      return try ValidateRequest(
        config: validate,
        overrides: overrides,
        configDirectory: configURL.deletingLastPathComponent()
      )
    }

    guard let modelPath = command.modelPath else {
      throw ToolingFailure.user(
        .configInvalid,
        "--model-path is required when --config is not used."
      )
    }
    guard let sourceDir = command.sourceDir else {
      throw ToolingFailure.user(
        .configInvalid,
        "--source-dir is required when --config is not used."
      )
    }
    guard let moduleName = command.moduleName else {
      throw ToolingFailure.user(
        .configInvalid,
        "--module-name is required when --config is not used."
      )
    }

    let template = ValidateTemplate(
      modelPath: makeAbsoluteURL(fromCLIPath: modelPath).path,
      modelVersion: command.modelVersion,
      momcBin: command.momcBin.map { makeAbsoluteURL(fromCLIPath: $0).path },
      sourceDir: makeAbsoluteURL(fromCLIPath: sourceDir).path,
      moduleName: moduleName,
      typeMappings: nil,
      attributeRules: nil,
      accessLevel: command.accessLevel,
      singleFile: command.singleFile,
      splitByEntity: command.splitByEntity,
      headerTemplate: command.headerTemplate.map { makeAbsoluteURL(fromCLIPath: $0).path },
      generateInit: command.generateInit,
      relationshipSetterPolicy: command.relationshipSetterPolicy,
      relationshipCountPolicy: command.relationshipCountPolicy,
      defaultDecodeFailurePolicy: command.defaultDecodeFailurePolicy,
      include: splitCSVPatterns(command.include),
      exclude: splitCSVPatterns(command.exclude),
      level: command.level,
      report: command.report,
      failOnWarning: command.failOnWarning,
      maxIssues: command.maxIssues
    )

    return try ValidateRequest(config: template)
  }

  static func emitResult(_ result: ValidateResult, report: ToolingReportFormat) throws {
    switch report {
    case .text:
      emitText(result)
    case .json:
      try emitJSON(result)
    case .sarif:
      try emitSARIF(result)
    }
  }

  static func failureIfNeeded(
    for result: ValidateResult,
    failOnWarning: Bool
  ) -> ToolingFailure? {
    if result.errorCount > 0 {
      return .user(
        .validationFailed,
        "validate found \(result.errorCount) error(s) and \(result.warningCount) warning(s)."
      )
    }

    if failOnWarning && result.warningCount > 0 {
      return .user(
        .validationFailed,
        "validate found \(result.warningCount) warning(s) and failOnWarning is enabled."
      )
    }

    return nil
  }

  private static func emitText(_ result: ValidateResult) {
    for diagnostic in result.diagnostics {
      emitDiagnostic(diagnostic)
    }

    emitInfo(
      "validate completed with \(result.errorCount) error(s) and \(result.warningCount) warning(s)."
    )
  }

  private static func emitJSON(_ result: ValidateResult) throws {
    let data = try encodeToolingJSON(result)
    guard let text = String(data: data, encoding: .utf8) else {
      throw ToolingFailure.runtime(
        .jsonEncodeFailed,
        "failed to encode validate result as UTF-8."
      )
    }
    print(text)
  }

  private static func emitSARIF(_ result: ValidateResult) throws {
    let severityMap: [ToolingDiagnosticSeverity: String] = [
      .error: "error",
      .warning: "warning",
      .note: "note",
    ]

    let results: [[String: Any?]] = result.diagnostics.map { diagnostic in
      [
        "level": severityMap[diagnostic.severity] ?? "warning",
        "message": ["text": diagnostic.message],
        "ruleId": diagnostic.code?.rawValue,
      ]
    }

    let sarif: [String: Any] = [
      "$schema": "https://json.schemastore.org/sarif-2.1.0.json",
      "version": "2.1.0",
      "runs": [
        [
          "tool": [
            "driver": [
              "name": "cde-tool"
            ]
          ],
          "results": results.map { dictionary in
            dictionary.compactMapValues { $0 }
          },
        ]
      ],
    ]

    let data = try JSONSerialization.data(
      withJSONObject: sarif, options: [.prettyPrinted, .sortedKeys])
    guard let text = String(data: data, encoding: .utf8) else {
      throw ToolingFailure.runtime(
        .jsonEncodeFailed,
        "failed to encode SARIF report as UTF-8."
      )
    }
    print(text)
  }

  private static func splitCSVPatterns(_ patterns: String?) -> [String]? {
    guard let patterns else { return nil }
    return
      patterns
      .split(separator: ",")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { $0.isEmpty == false }
  }

  private static func makeAbsoluteURL(fromCLIPath path: String) -> URL {
    if (path as NSString).isAbsolutePath {
      return URL(fileURLWithPath: path)
    }
    return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
      .appendingPathComponent(path)
  }
}
