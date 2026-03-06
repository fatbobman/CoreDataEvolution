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

@Suite("Tooling Core Inspect Service Tests")
struct InspectServiceTests {
  @Test("inspect service emits reusable IR json for the integration model")
  func inspectServiceBuildsJSONForIntegrationModel() throws {
    let repositoryRoot = try findRepositoryRoot()
    let modelPath =
      repositoryRoot
      .appendingPathComponent("Models")
      .appendingPathComponent("Integration")
      .appendingPathComponent("CoreDataEvolutionIntegrationModel.xcdatamodeld")

    let result = try InspectService.run(
      .init(
        modelPath: modelPath.path,
        modelVersion: nil,
        momcBin: nil
      )
    )

    #expect(result.modelIR.entities.contains(where: { $0.name == "CDEItem" }))
    #expect(result.modelIR.source.inputKind == .xcdatamodeld)
    #expect(result.jsonData.isEmpty == false)
    #expect(
      result.diagnostics.contains(where: {
        $0.message.contains("location") && $0.severity == .warning
      })
    )

    let json = try #require(String(data: result.jsonData, encoding: .utf8))
    #expect(json.contains("\"entities\""))
    #expect(json.contains("\"generationPolicy\""))
    #expect(json.contains("\"CDEItem\""))
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
}
