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
  private func replacingFinalTypeBrace(
    in contents: String,
    with replacement: String
  ) -> String {
    let finalBraceRange = try! #require(contents.range(of: "\n}", options: .backwards))
    var updated = contents
    updated.replaceSubrange(finalBraceRange, with: replacement)
    return updated
  }

  @Test("validate conformance accepts generated sources")
  func validateConformanceAcceptsGeneratedSources() throws {
    let fixture = try makeValidationFixture()
    defer { fixture.cleanUp() }

    let result = try ValidateService.run(
      makeValidateRequest(
        sourceDirectory: fixture.sourceDirectory.path,
        modelPath: fixture.modelPath)
    )

    #expect(result.errorCount == 0)
    #expect(result.warningCount == 0)
    #expect(result.diagnostics.isEmpty)
    #expect(result.sourceIR.entities.count == 2)
  }

  @Test("validate conformance accepts generated relationship renames from relationship rules")
  func validateConformanceAcceptsGeneratedRelationshipRenames() throws {
    let fixture = try makeValidationFixture(
      relationshipRules: .init(
        entities: [
          "CDEItem": [
            "tag": .init(swiftName: "ownerTag")
          ],
          "CDETag": [
            "items": .init(swiftName: "ownedItems")
          ],
        ]
      )
    )
    defer { fixture.cleanUp() }

    let result = try ValidateService.run(
      makeValidateRequest(
        sourceDirectory: fixture.sourceDirectory.path,
        modelPath: fixture.modelPath,
        relationshipRules: .init(
          entities: [
            "CDEItem": [
              "tag": .init(swiftName: "ownerTag")
            ],
            "CDETag": [
              "items": .init(swiftName: "ownedItems")
            ],
          ]
        )
      )
    )

    #expect(result.errorCount == 0)
    #expect(result.warningCount == 0)
    #expect(result.diagnostics.isEmpty)
  }

  @Test("validate allows extra ignore property")
  func validateAllowsExtraIgnoreProperty() throws {
    let fixture = try makeValidationFixture()
    defer { fixture.cleanUp() }

    try rewriteEntityFile(
      named: "CDEItem+CoreDataEvolution.swift",
      in: fixture.sourceDirectory
    ) { contents in
      replacingFinalTypeBrace(
        in: contents,
        with: """

            @Ignore
            var scratch: String = ""
          }
          """
      )
    }

    let result = try ValidateService.run(
      makeValidateRequest(
        sourceDirectory: fixture.sourceDirectory.path,
        modelPath: fixture.modelPath)
    )

    #expect(result.errorCount == 0)
  }

  @Test("validate rejects extra stored property without ignore")
  func validateRejectsExtraStoredPropertyWithoutIgnore() throws {
    let fixture = try makeValidationFixture()
    defer { fixture.cleanUp() }

    try rewriteEntityFile(
      named: "CDEItem+CoreDataEvolution.swift",
      in: fixture.sourceDirectory
    ) { contents in
      replacingFinalTypeBrace(
        in: contents,
        with: """

            var scratch: String = ""
          }
          """
      )
    }

    let result = try ValidateService.run(
      makeValidateRequest(
        sourceDirectory: fixture.sourceDirectory.path,
        modelPath: fixture.modelPath)
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
    let fixture = try makeValidationFixture()
    defer { fixture.cleanUp() }

    try rewriteEntityFile(
      named: "CDEItem+CoreDataEvolution.swift",
      in: fixture.sourceDirectory
    ) { contents in
      contents.replacingOccurrences(
        of: #"var title: String = """#,
        with: #"var title: String = "wrong""#
      )
    }

    let result = try ValidateService.run(
      makeValidateRequest(
        sourceDirectory: fixture.sourceDirectory.path,
        modelPath: fixture.modelPath)
    )

    #expect(result.errorCount == 1)
    #expect(
      result.diagnostics.contains {
        $0.message.contains("default value mismatch for 'CDEItem.title'")
      }
    )
  }

  @Test("validate rejects non-nil defaults for optional codable storage")
  func validateRejectsNonNilDefaultsForOptionalCodableStorage() throws {
    let fixture = try makeValidationFixture()
    defer { fixture.cleanUp() }

    try rewriteEntityFile(
      named: "CDEItem+CoreDataEvolution.swift",
      in: fixture.sourceDirectory
    ) { contents in
      contents.replacingOccurrences(
        of: "var config: CDEItemConfig? = nil",
        with: "var config: CDEItemConfig? = .init()"
      )
    }

    let result = try ValidateService.run(
      makeValidateRequest(
        sourceDirectory: fixture.sourceDirectory.path,
        modelPath: fixture.modelPath)
    )

    #expect(result.errorCount == 1)
    #expect(
      result.diagnostics.contains {
        $0.message.contains(
          "only allows nil as an explicit default for optional codable storage at 'CDEItem.config'"
        )
      }
    )
  }

  @Test("validate rejects multi-binding stored properties")
  func validateRejectsMultiBindingStoredProperties() throws {
    let fixture = try makeValidationFixture()
    defer { fixture.cleanUp() }

    try rewriteEntityFile(
      named: "CDEItem+CoreDataEvolution.swift",
      in: fixture.sourceDirectory
    ) { contents in
      contents.replacingOccurrences(
        of: #"var title: String = """#,
        with: #"var title: String = "", subtitle: String = """#
      )
    }

    do {
      _ = try ValidateService.run(
        makeValidateRequest(
          sourceDirectory: fixture.sourceDirectory.path,
          modelPath: fixture.modelPath)
      )
      Issue.record("Expected validate to reject multi-binding stored properties.")
    } catch let failure as ToolingFailure {
      #expect(failure.code == .validationFailed)
      #expect(
        failure.message.contains(
          "multiple stored properties in one `var` declaration inside @PersistentModel class 'CDEItem'"
        )
      )
    }
  }

  @Test("validate rejects unique trait drift")
  func validateRejectsUniqueTraitDrift() throws {
    let fixture = try makeValidationFixture()
    defer { fixture.cleanUp() }

    try rewriteEntityFile(
      named: "CDEItem+CoreDataEvolution.swift",
      in: fixture.sourceDirectory
    ) { contents in
      contents.replacingOccurrences(
        of: #"@Attribute(.unique, persistentName: "name")"#,
        with: #"@Attribute(persistentName: "name")"#
      )
    }

    let result = try ValidateService.run(
      makeValidateRequest(
        sourceDirectory: fixture.sourceDirectory.path,
        modelPath: fixture.modelPath)
    )

    #expect(result.errorCount == 1)
    #expect(
      result.diagnostics.contains {
        $0.message.contains("unique mismatch for 'CDEItem.title'")
      }
    )
  }

  @Test("validate rejects transient trait drift")
  func validateRejectsTransientTraitDrift() throws {
    let fixture = try makeValidationFixture { contents in
      contents.replacingOccurrences(
        of: #"<attribute name="keywords_payload" optional="YES" attributeType="String"/>"#,
        with: """
          <attribute name="keywords_payload" optional="YES" attributeType="String"/>
                <attribute name="scratch" optional="YES" attributeType="String" transient="YES"/>
          """
      )
    }
    defer { fixture.cleanUp() }

    try rewriteEntityFile(
      named: "CDEItem+CoreDataEvolution.swift",
      in: fixture.sourceDirectory
    ) { contents in
      contents.replacingOccurrences(
        of: "@Attribute(.transient)",
        with: "@Attribute"
      )
    }

    let result = try ValidateService.run(
      makeValidateRequest(
        sourceDirectory: fixture.sourceDirectory.path,
        modelPath: fixture.modelPath)
    )

    #expect(result.errorCount == 1)
    #expect(
      result.diagnostics.contains {
        $0.message.contains("transient mismatch for 'CDEItem.scratch'")
      }
    )
  }

  @Test("validate emits note for custom members inside persistent model class")
  func validateEmitsNoteForCustomMembersInsideClass() throws {
    let fixture = try makeValidationFixture()
    defer { fixture.cleanUp() }

    try rewriteEntityFile(
      named: "CDEItem+CoreDataEvolution.swift",
      in: fixture.sourceDirectory
    ) { contents in
      replacingFinalTypeBrace(
        in: contents,
        with: """

            var displayTitle: String { title }

            func configureForUI() {}
          }
          """
      )
    }

    let result = try ValidateService.run(
      makeValidateRequest(
        sourceDirectory: fixture.sourceDirectory.path,
        modelPath: fixture.modelPath)
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
    let fixture = try makeValidationFixture()
    defer { fixture.cleanUp() }

    let result = try ValidateService.run(
      makeValidateRequest(
        sourceDirectory: fixture.sourceDirectory.path,
        modelPath: fixture.modelPath,
        level: .exact
      )
    )

    #expect(result.errorCount == 0)
  }

  @Test("validate exact rejects managed file drift")
  func validateExactRejectsManagedFileDrift() throws {
    let fixture = try makeValidationFixture()
    defer { fixture.cleanUp() }

    try rewriteEntityFile(
      named: "CDEItem+CoreDataEvolution.swift",
      in: fixture.sourceDirectory
    ) { contents in
      contents.replacingOccurrences(
        of: "var title: String = \"\"", with: "var title: String = \"drift\"")
    }

    let result = try ValidateService.run(
      makeValidateRequest(
        sourceDirectory: fixture.sourceDirectory.path,
        modelPath: fixture.modelPath,
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

  private func makeValidationFixture(
    mutateContents: ((String) -> String)? = nil,
    relationshipRules: ToolingRelationshipRules = .init()
  ) throws -> (
    modelPath: String, sourceDirectory: URL, cleanUp: () -> Void
  ) {
    let modelPath = try makeToolingSourceModelFixture(mutateContents: mutateContents).path
    let temporaryDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("CoreDataEvolutionToolingCoreTests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(
      at: temporaryDirectory,
      withIntermediateDirectories: true
    )

    let generateResult = try GenerateService.run(
      makeGenerateRequest(
        outputDirectory: temporaryDirectory.path,
        modelPath: modelPath,
        relationshipRules: relationshipRules
      ))
    for file in generateResult.filePlan {
      let outputURL = temporaryDirectory.appendingPathComponent(file.relativePath)
      try FileManager.default.createDirectory(
        at: outputURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      try file.contents.write(to: outputURL, atomically: true, encoding: .utf8)
    }
    return (
      modelPath,
      temporaryDirectory,
      {
        try? FileManager.default.removeItem(at: temporaryDirectory)
        try? FileManager.default.removeItem(
          at: URL(fileURLWithPath: modelPath).deletingLastPathComponent())
      }
    )
  }

  private func makeGenerateRequest(
    outputDirectory: String,
    modelPath: String,
    relationshipRules: ToolingRelationshipRules = .init()
  ) throws
    -> GenerateRequest
  {
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
              transformerName: "CDEStringListTransformer"
            ),
          ]
        ]
      ),
      relationshipRules: relationshipRules,
      accessLevel: .internal,
      singleFile: false,
      splitByEntity: true,
      overwrite: .all,
      cleanStale: false,
      dryRun: true,
      format: .none,
      headerTemplate: nil,
      generateInit: true,
      defaultDecodeFailurePolicy: .debugAssertNil
    )
  }

  private func makeValidateRequest(
    sourceDirectory: String,
    modelPath: String,
    level: ToolingValidationLevel = .conformance,
    relationshipRules: ToolingRelationshipRules = .init()
  ) -> ValidateRequest {
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
              transformerName: "CDEStringListTransformer"
            ),
          ]
        ]
      ),
      relationshipRules: relationshipRules,
      accessLevel: .internal,
      singleFile: false,
      splitByEntity: true,
      headerTemplate: nil,
      generateInit: true,
      defaultDecodeFailurePolicy: .debugAssertNil,
      include: [],
      exclude: [],
      level: level,
      report: .text,
      failOnWarning: false,
      maxIssues: 50
    )
  }

  private func findRepositoryRoot(filePath: String = #filePath) throws -> URL {
    try findToolingRepositoryRoot(filePath: filePath)
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
