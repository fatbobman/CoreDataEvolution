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
  @Test("validate CLI emits JSON report for clean conformance validation")
  func validateCLIEmitsJSONReport() throws {
    let fixture = try makeGeneratedSourceFixture()
    defer { fixture.cleanUp() }

    let configURL = try writeToolingConfig(
      .init(
        schemaVersion: toolingSupportedSchemaVersion,
        generate: nil,
        validate: .init(
          modelPath: fixture.modelPath,
          modelVersion: nil,
          momcBin: nil,
          sourceDir: fixture.sourceDirectory.path,
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
          level: .conformance,
          report: .text,
          failOnWarning: false,
          maxIssues: 50
        )
      ),
      fileName: "validate.json"
    )
    defer { try? FileManager.default.removeItem(at: configURL.deletingLastPathComponent()) }

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

  @Test("validate CLI emits SARIF and non-zero exit code for exact drift")
  func validateCLIEmitsSARIFForExactDrift() throws {
    let fixture = try makeGeneratedSourceFixture()
    defer { fixture.cleanUp() }

    try rewriteEntityFile(
      named: "CDEItem+CoreDataEvolution.swift",
      in: fixture.sourceDirectory
    ) { contents in
      contents.replacingOccurrences(
        of: "var title: String = \"\"",
        with: "var title: String = \"drift\"")
    }

    let configURL = try writeToolingConfig(
      .init(
        schemaVersion: toolingSupportedSchemaVersion,
        generate: nil,
        validate: .init(
          modelPath: fixture.modelPath,
          modelVersion: nil,
          momcBin: nil,
          sourceDir: fixture.sourceDirectory.path,
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
          level: .exact,
          report: .text,
          failOnWarning: false,
          maxIssues: 50
        )
      ),
      fileName: "validate.json"
    )
    defer { try? FileManager.default.removeItem(at: configURL.deletingLastPathComponent()) }

    let result = try runTool([
      "validate",
      "--config", configURL.path,
      "--report", "sarif",
    ])

    #expect(result.exitCode == 1)
    #expect(result.stdout.contains("\"version\" : \"2.1.0\""))
    #expect(result.stdout.contains("\"ruleId\" : \"TOOL-VALIDATION-FAILED\""))
  }
}
