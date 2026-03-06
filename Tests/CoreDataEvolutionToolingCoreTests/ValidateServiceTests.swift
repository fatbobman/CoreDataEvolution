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

@Suite("Tooling Core Validate Service Tests")
struct ValidateServiceTests {
  @Test("validate conformance accepts generated sources")
  func validateConformanceAcceptsGeneratedSources() throws {
    let sourceDirectory = try makeGeneratedSourceDirectory()
    defer { try? FileManager.default.removeItem(at: sourceDirectory) }

    let result = try ValidateService.run(
      makeValidateRequest(sourceDirectory: sourceDirectory.path)
    )

    #expect(result.errorCount == 0)
    #expect(result.warningCount == 0)
    #expect(result.diagnostics.isEmpty)
    #expect(result.sourceIR.entities.count == 2)
  }

  @Test("validate allows extra ignore property")
  func validateAllowsExtraIgnoreProperty() throws {
    let sourceDirectory = try makeGeneratedSourceDirectory()
    defer { try? FileManager.default.removeItem(at: sourceDirectory) }

    try rewriteEntityFile(
      named: "CDEItem+CoreDataEvolution.swift",
      in: sourceDirectory
    ) { contents in
      contents.replacingOccurrences(
        of: "\n}\n\nextension CDEItem: PersistentEntity {}",
        with: """

            @Ignore
            var scratch: String = ""
          }

          extension CDEItem: PersistentEntity {}
          """
      )
    }

    let result = try ValidateService.run(
      makeValidateRequest(sourceDirectory: sourceDirectory.path)
    )

    #expect(result.errorCount == 0)
  }

  @Test("validate rejects extra stored property without ignore")
  func validateRejectsExtraStoredPropertyWithoutIgnore() throws {
    let sourceDirectory = try makeGeneratedSourceDirectory()
    defer { try? FileManager.default.removeItem(at: sourceDirectory) }

    try rewriteEntityFile(
      named: "CDEItem+CoreDataEvolution.swift",
      in: sourceDirectory
    ) { contents in
      contents.replacingOccurrences(
        of: "\n}\n\nextension CDEItem: PersistentEntity {}",
        with: """

            var scratch: String = ""
          }

          extension CDEItem: PersistentEntity {}
          """
      )
    }

    let result = try ValidateService.run(
      makeValidateRequest(sourceDirectory: sourceDirectory.path)
    )

    #expect(result.errorCount == 1)
    #expect(
      result.diagnostics.contains {
        $0.message.contains("extra stored property 'CDEItem.scratch'")
      }
    )
  }

  @Test("validate rejects default value drift")
  func validateRejectsDefaultValueDrift() throws {
    let sourceDirectory = try makeGeneratedSourceDirectory()
    defer { try? FileManager.default.removeItem(at: sourceDirectory) }

    try rewriteEntityFile(
      named: "CDEItem+CoreDataEvolution.swift",
      in: sourceDirectory
    ) { contents in
      contents.replacingOccurrences(
        of: #"var title: String = """#,
        with: #"var title: String = "wrong""#
      )
    }

    let result = try ValidateService.run(
      makeValidateRequest(sourceDirectory: sourceDirectory.path)
    )

    #expect(result.errorCount == 1)
    #expect(
      result.diagnostics.contains {
        $0.message.contains("default value mismatch for 'CDEItem.title'")
      }
    )
  }

  @Test("validate emits note for custom members inside persistent model class")
  func validateEmitsNoteForCustomMembersInsideClass() throws {
    let sourceDirectory = try makeGeneratedSourceDirectory()
    defer { try? FileManager.default.removeItem(at: sourceDirectory) }

    try rewriteEntityFile(
      named: "CDEItem+CoreDataEvolution.swift",
      in: sourceDirectory
    ) { contents in
      contents.replacingOccurrences(
        of: "\n}\n\nextension CDEItem: PersistentEntity {}",
        with: """

            var displayTitle: String { title }

            func configureForUI() {}
          }

          extension CDEItem: PersistentEntity {}
          """
      )
    }

    let result = try ValidateService.run(
      makeValidateRequest(sourceDirectory: sourceDirectory.path)
    )

    #expect(result.errorCount == 0)
    #expect(
      result.diagnostics.contains {
        $0.severity == .note && $0.message.contains("custom members inside 'CDEItem'")
      }
    )
  }

  @Test("validate exact accepts generated managed files")
  func validateExactAcceptsGeneratedManagedFiles() throws {
    let sourceDirectory = try makeGeneratedSourceDirectory()
    defer { try? FileManager.default.removeItem(at: sourceDirectory) }

    let result = try ValidateService.run(
      makeValidateRequest(
        sourceDirectory: sourceDirectory.path,
        level: .exact
      )
    )

    #expect(result.errorCount == 0)
  }

  @Test("validate exact rejects managed file drift")
  func validateExactRejectsManagedFileDrift() throws {
    let sourceDirectory = try makeGeneratedSourceDirectory()
    defer { try? FileManager.default.removeItem(at: sourceDirectory) }

    try rewriteEntityFile(
      named: "CDEItem+CoreDataEvolution.swift",
      in: sourceDirectory
    ) { contents in
      contents.replacingOccurrences(
        of: "var title: String = \"\"", with: "var title: String = \"drift\"")
    }

    let result = try ValidateService.run(
      makeValidateRequest(
        sourceDirectory: sourceDirectory.path,
        level: .exact
      )
    )

    #expect(result.errorCount > 0)
    #expect(
      result.diagnostics.contains {
        $0.message.contains("content drift in managed file 'CDEItem+CoreDataEvolution.swift'")
      }
    )
  }

  private func makeGeneratedSourceDirectory() throws -> URL {
    let temporaryDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("CoreDataEvolutionToolingCoreTests", isDirectory: true)
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
      attributeRules: .init(
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
      ),
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

  private func makeValidateRequest(
    sourceDirectory: String,
    level: ToolingValidationLevel = .conformance
  ) throws -> ValidateRequest {
    let modelPath = try integrationModelPath()
    return .init(
      modelPath: modelPath,
      modelVersion: nil,
      momcBin: nil,
      sourceDir: sourceDirectory,
      moduleName: "AppModels",
      typeMappings: makeDefaultToolingTypeMappings(),
      attributeRules: .init(
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
      ),
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
  }

  private func integrationModelPath(filePath: String = #filePath) throws -> String {
    let repositoryRoot = try findRepositoryRoot(filePath: filePath)
    return
      repositoryRoot
      .appendingPathComponent("Models")
      .appendingPathComponent("Integration")
      .appendingPathComponent("CoreDataEvolutionIntegrationModel.xcdatamodeld")
      .path
  }

  private func findRepositoryRoot(filePath: String = #filePath) throws -> URL {
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
}
