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

@Suite("Tooling Core Generate Service Tests")
struct GenerateServiceTests {
  @Test("generate service renders integration model sources from rules")
  func generateServiceRendersIntegrationModelSources() throws {
    let modelPath = try makeToolingSourceModelFixture()
    defer { try? FileManager.default.removeItem(at: modelPath.deletingLastPathComponent()) }

    let result = try GenerateService.run(
      .init(
        modelPath: modelPath.path,
        modelVersion: nil,
        momcBin: nil,
        outputDir: "Generated/CoreDataEvolution",
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
        overwrite: .none,
        cleanStale: false,
        dryRun: true,
        format: .none,
        headerTemplate: "// GENERATED",
        generateInit: false,
        relationshipSetterPolicy: .warning,
        relationshipCountPolicy: .none,
        defaultDecodeFailurePolicy: .fallbackToDefaultValue
      )
    )

    #expect(result.generatedSources.count == 2)
    #expect(result.filePlan.count == 2)
    #expect(result.writeResult.dryRun)
    #expect(result.writeResult.operations.filter { $0.kind == .create }.count == 2)
    #expect(result.diagnostics.isEmpty)

    let itemSource = try #require(
      result.generatedSources.first(where: { $0.entityName == "CDEItem" })
    )
    #expect(itemSource.suggestedFileName == "CDEItem+CoreDataEvolution.swift")
    #expect(itemSource.contents.contains("// GENERATED"))
    #expect(itemSource.contents.contains("@objc(CDEItem)"))
    #expect(itemSource.contents.contains("@PersistentModel(relationshipSetterPolicy: .warning)"))
    #expect(itemSource.contents.contains(#"@Attribute(.unique, originalName: "name")"#))
    #expect(itemSource.contents.contains(#"var title: String = """#))
    #expect(
      itemSource.contents.contains(
        #"@Attribute(originalName: "status_raw", storageMethod: .raw, decodeFailurePolicy: .fallbackToDefaultValue)"#
      ))
    #expect(itemSource.contents.contains("var status: CDEItemStatus? = nil"))
    #expect(
      itemSource.contents.contains(
        #"@Attribute(originalName: "config_blob", storageMethod: .codable, decodeFailurePolicy: .fallbackToDefaultValue)"#
      ))
    #expect(itemSource.contents.contains("var config: CDEItemConfig? = nil"))
    #expect(itemSource.contents.contains(#"@Attribute(storageMethod: .composition)"#))
    #expect(itemSource.contents.contains("var location: CDEItemLocation? = nil"))
    #expect(
      itemSource.contents.contains(
        #"@Attribute(originalName: "keywords_payload", storageMethod: .transformed(CDEStringListTransformer.self), decodeFailurePolicy: .fallbackToDefaultValue)"#
      ))
    #expect(itemSource.contents.contains("var keywords: [String]? = nil"))
    #expect(itemSource.contents.contains("var tag: CDETag?"))

    let tagSource = try #require(
      result.generatedSources.first(where: { $0.entityName == "CDETag" })
    )
    #expect(tagSource.contents.contains("var items: Set<CDEItem>"))
    #expect(tagSource.contents.contains("var label: String = \"\""))

    let itemPlan = try #require(
      result.filePlan.first(where: { $0.relativePath == "CDEItem+CoreDataEvolution.swift" })
    )
    #expect(itemPlan.contents.contains(toolingManagedFileMarker))
  }

  @Test("generate service supports single-file output")
  func generateServiceSupportsSingleFileOutput() throws {
    let repositoryRoot = try findRepositoryRoot()
    let modelPath = try makeToolingSourceModelFixture()
    defer { try? FileManager.default.removeItem(at: modelPath.deletingLastPathComponent()) }

    let result = try GenerateService.run(
      .init(
        modelPath: modelPath.path,
        modelVersion: nil,
        momcBin: nil,
        outputDir: repositoryRoot.appendingPathComponent(".build").path,
        moduleName: "AppModels",
        typeMappings: makeDefaultToolingTypeMappings(),
        attributeRules: .init(
          entities: [
            "CDEItem": [
              "location": .init(swiftType: "CDEItemLocation", storageMethod: .composition)
            ]
          ]
        ),
        accessLevel: .internal,
        singleFile: true,
        splitByEntity: false,
        overwrite: .changed,
        cleanStale: false,
        dryRun: true,
        format: .none,
        headerTemplate: nil,
        generateInit: false,
        relationshipSetterPolicy: .warning,
        relationshipCountPolicy: .none,
        defaultDecodeFailurePolicy: .fallbackToDefaultValue
      )
    )

    #expect(result.generatedSources.count == 1)
    #expect(result.filePlan.count == 1)
    #expect(result.generatedSources[0].suggestedFileName == "AppModels+CoreDataEvolution.swift")
    #expect(result.generatedSources[0].contents.contains("@objc(CDEItem)"))
    #expect(result.generatedSources[0].contents.contains("@objc(CDETag)"))
  }

  @Test("generate service emits companion extension stubs when enabled")
  func generateServiceEmitsCompanionExtensionStubs() throws {
    let repositoryRoot = try findRepositoryRoot()
    let outputDirectory = repositoryRoot.appendingPathComponent(
      ".build/ToolingStubTests", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: outputDirectory) }

    let modelPath = try makeToolingSourceModelFixture()
    defer { try? FileManager.default.removeItem(at: modelPath.deletingLastPathComponent()) }

    let result = try GenerateService.run(
      .init(
        modelPath: modelPath.path,
        modelVersion: nil,
        momcBin: nil,
        outputDir: outputDirectory.path,
        moduleName: "AppModels",
        typeMappings: makeDefaultToolingTypeMappings(),
        attributeRules: .init(
          entities: [
            "CDEItem": [
              "location": .init(swiftType: "CDEItemLocation", storageMethod: .composition)
            ]
          ]
        ),
        accessLevel: .internal,
        singleFile: false,
        splitByEntity: true,
        overwrite: .changed,
        cleanStale: false,
        dryRun: true,
        format: .none,
        headerTemplate: nil,
        emitExtensionStubs: true,
        generateInit: false,
        relationshipSetterPolicy: .warning,
        relationshipCountPolicy: .none,
        defaultDecodeFailurePolicy: .fallbackToDefaultValue
      )
    )

    #expect(result.generatedSources.count == 4)
    #expect(result.filePlan.count == 4)

    let stubSource = try #require(
      result.generatedSources.first(where: { $0.suggestedFileName == "CDEItem+Extensions.swift" })
    )
    #expect(stubSource.management == .companionStub)
    #expect(stubSource.contents.contains("Add methods and computed properties"))

    let stubPlan = try #require(
      result.filePlan.first(where: { $0.relativePath == "CDEItem+Extensions.swift" })
    )
    #expect(stubPlan.management == .companionStub)
    #expect(stubPlan.contents.contains(toolingManagedFileMarker) == false)
  }

  private func findRepositoryRoot(filePath: String = #filePath) throws -> URL {
    try findToolingRepositoryRoot(filePath: filePath)
  }
}
