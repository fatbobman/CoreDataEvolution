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
import Testing

@Suite("CDETool Validate CLI Tests")
struct ValidateCLITests {
  @Test("validate CLI emits JSON report for clean quick validation")
  func validateCLIEmitsJSONReport() throws {
    let sourceDirectory = try makeGeneratedSourceDirectory()
    defer { try? FileManager.default.removeItem(at: sourceDirectory) }

    let configURL = try writeValidateConfig(
      sourceDirectory: sourceDirectory.path,
      level: .quick
    )
    defer { try? FileManager.default.removeItem(at: configURL) }

    let result = try runTool([
      "validate",
      "--config", configURL.path,
      "--report", "json",
    ])

    #expect(result.exitCode == 0)

    let data = try #require(result.stdout.data(using: .utf8))
    let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(json["errorCount"] as? Int == 0)
    #expect(json["warningCount"] as? Int == 0)
  }

  @Test("validate CLI emits SARIF and non-zero exit code for strict drift")
  func validateCLIEmitsSARIFForStrictDrift() throws {
    let sourceDirectory = try makeGeneratedSourceDirectory()
    defer { try? FileManager.default.removeItem(at: sourceDirectory) }

    try rewriteEntityFile(
      named: "CDEItem+CoreDataEvolution.swift",
      in: sourceDirectory
    ) { contents in
      contents.replacingOccurrences(
        of: "var title: String = \"\"", with: "var title: String = \"drift\"")
    }

    let configURL = try writeValidateConfig(
      sourceDirectory: sourceDirectory.path,
      level: .strict
    )
    defer { try? FileManager.default.removeItem(at: configURL) }

    let result = try runTool([
      "validate",
      "--config", configURL.path,
      "--report", "sarif",
    ])

    #expect(result.exitCode == 1)
    #expect(result.stdout.contains("\"version\" : \"2.1.0\""))
    #expect(result.stdout.contains("\"ruleId\" : \"TOOL-VALIDATION-FAILED\""))
  }

  private func makeGeneratedSourceDirectory() throws -> URL {
    let temporaryDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("CDEToolTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(
      at: temporaryDirectory,
      withIntermediateDirectories: true
    )

    let generateResult = try GenerateService.run(
      makeGenerateRequest(outputDirectory: temporaryDirectory.path))
    for file in generateResult.filePlan {
      let outputURL = temporaryDirectory.appendingPathComponent(file.relativePath)
      try FileManager.default.createDirectory(
        at: outputURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      try file.contents.write(to: outputURL, atomically: true, encoding: .utf8)
    }
    return temporaryDirectory
  }

  private func makeGenerateRequest(outputDirectory: String) throws -> GenerateRequest {
    let modelPath = try integrationModelPath()
    return .init(
      modelPath: modelPath,
      modelVersion: nil,
      momcBin: nil,
      outputDir: outputDirectory,
      moduleName: "AppModels",
      typeMappings: makeDefaultToolingTypeMappings(),
      attributeRules: makeIntegrationAttributeRules(),
      accessLevel: .internal,
      singleFile: false,
      splitByEntity: true,
      overwrite: .all,
      cleanStale: false,
      dryRun: true,
      format: .none,
      headerTemplate: nil,
      generateInit: true,
      relationshipSetterPolicy: .plain,
      relationshipCountPolicy: .warning,
      defaultDecodeFailurePolicy: .debugAssertNil
    )
  }

  private func writeValidateConfig(
    sourceDirectory: String,
    level: ToolingValidationLevel
  ) throws -> URL {
    let temporaryDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("CDEToolTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(
      at: temporaryDirectory,
      withIntermediateDirectories: true
    )

    let template = ToolingConfigTemplate(
      schemaVersion: toolingSupportedSchemaVersion,
      generate: nil,
      validate: .init(
        modelPath: try integrationModelPath(),
        modelVersion: nil,
        momcBin: nil,
        sourceDir: sourceDirectory,
        moduleName: "AppModels",
        typeMappings: makeDefaultToolingTypeMappings(),
        attributeRules: makeIntegrationAttributeRules(),
        accessLevel: .internal,
        singleFile: false,
        splitByEntity: true,
        headerTemplate: nil,
        generateInit: true,
        relationshipSetterPolicy: .plain,
        relationshipCountPolicy: .warning,
        defaultDecodeFailurePolicy: .debugAssertNil,
        include: [],
        exclude: [],
        level: level,
        report: .text,
        failOnWarning: false,
        maxIssues: 50
      )
    )

    let configURL = temporaryDirectory.appendingPathComponent("validate.json")
    try encodeToolingJSON(template).write(to: configURL)
    return configURL
  }

  private func runTool(_ arguments: [String]) throws -> (
    exitCode: Int32, stdout: String, stderr: String
  ) {
    let process = Process()
    process.executableURL = try toolExecutableURL()
    process.arguments = arguments
    process.currentDirectoryURL = try repositoryRoot()

    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe

    try process.run()
    process.waitUntilExit()

    let stdout =
      String(
        data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(),
        encoding: .utf8
      ) ?? ""
    let stderr =
      String(
        data: stderrPipe.fileHandleForReading.readDataToEndOfFile(),
        encoding: .utf8
      ) ?? ""
    return (process.terminationStatus, stdout, stderr)
  }

  private func toolExecutableURL() throws -> URL {
    let buildDirectory = try repositoryRoot().appendingPathComponent(".build", isDirectory: true)
    guard
      let enumerator = FileManager.default.enumerator(
        at: buildDirectory,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
      )
    else {
      throw ToolingFailure.runtime(.internalError, "failed to enumerate .build directory.")
    }

    for case let fileURL as URL in enumerator {
      guard fileURL.lastPathComponent == "cde-tool" else { continue }
      let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
      guard values.isRegularFile == true else { continue }
      if FileManager.default.isExecutableFile(atPath: fileURL.path) {
        return fileURL
      }
    }

    throw ToolingFailure.runtime(.internalError, "failed to locate built cde-tool executable.")
  }

  private func integrationModelPath(filePath: String = #filePath) throws -> String {
    let root = try repositoryRoot(filePath: filePath)
    return
      root
      .appendingPathComponent("Models")
      .appendingPathComponent("Integration")
      .appendingPathComponent("CoreDataEvolutionIntegrationModel.xcdatamodeld")
      .path
  }

  private func repositoryRoot(filePath: String = #filePath) throws -> URL {
    var currentURL = URL(fileURLWithPath: filePath).deletingLastPathComponent()
    while currentURL.path != "/" {
      if FileManager.default.fileExists(
        atPath: currentURL.appendingPathComponent("Package.swift").path)
      {
        return currentURL
      }
      currentURL = currentURL.deletingLastPathComponent()
    }

    throw ToolingFailure.runtime(
      .internalError,
      "failed to locate repository root from '\(filePath)'."
    )
  }

  private func rewriteEntityFile(
    named fileName: String,
    in sourceDirectory: URL,
    transform: (String) -> String
  ) throws {
    let fileURL = sourceDirectory.appendingPathComponent(fileName)
    let contents = try String(contentsOf: fileURL, encoding: .utf8)
    try transform(contents).write(to: fileURL, atomically: true, encoding: .utf8)
  }

  private func makeIntegrationAttributeRules() -> ToolingAttributeRules {
    .init(
      entities: [
        "CDEItem": [
          "name": .init(swiftName: "title"),
          "status_raw": .init(
            swiftName: "status",
            swiftType: "CDEItemStatus",
            storageMethod: .raw
          ),
          "config_blob": .init(
            swiftName: "config",
            swiftType: "CDEItemConfig",
            storageMethod: .codable
          ),
          "location": .init(swiftType: "CDEItemLocation", storageMethod: .composition),
          "keywords_payload": .init(
            swiftName: "keywords",
            swiftType: "[String]",
            storageMethod: .transformed,
            transformerType: "CDEStringListTransformer"
          ),
        ]
      ]
    )
  }
}
