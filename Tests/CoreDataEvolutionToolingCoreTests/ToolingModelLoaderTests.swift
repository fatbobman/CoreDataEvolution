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

@Suite("Tooling Core Model Loader Tests")
struct ToolingModelLoaderTests {
  @Test("xcdatamodeld picks explicit version when provided")
  func explicitVersionWins() throws {
    let packageURL = try makeVersionedModelPackage(
      versions: ["V1.xcdatamodel", "V2.xcdatamodel"],
      currentVersion: "V1.xcdatamodel"
    )

    let resolved = try ToolingModelLoader.resolveModelInput(
      modelPath: packageURL.path,
      modelVersion: "V2"
    )

    #expect(resolved.kind == .xcdatamodeld)
    #expect(resolved.selectedVersionName == "V2.xcdatamodel")
    #expect(resolved.selectedSourceURL.lastPathComponent == "V2.xcdatamodel")
    #expect(resolved.compiledModelURL.pathExtension == "momd")
  }

  @Test("xcdatamodeld uses xccurrentversion when modelVersion is omitted")
  func currentVersionIsPreferred() throws {
    let packageURL = try makeVersionedModelPackage(
      versions: ["V1.xcdatamodel", "V2.xcdatamodel"],
      currentVersion: "V1.xcdatamodel"
    )

    let resolved = try ToolingModelLoader.resolveModelInput(
      modelPath: packageURL.path,
      modelVersion: nil
    )

    #expect(resolved.selectedVersionName == "V1.xcdatamodel")
  }

  @Test("xcdatamodeld rejects malformed xccurrentversion")
  func malformedCurrentVersionThrows() throws {
    let packageURL = try makeVersionedModelPackage(
      versions: ["V1.xcdatamodel"],
      currentVersion: nil
    )
    try Data("not-a-plist".utf8).write(to: packageURL.appendingPathComponent(".xccurrentversion"))

    do {
      _ = try ToolingModelLoader.resolveModelInput(
        modelPath: packageURL.path,
        modelVersion: nil
      )
      Issue.record("Expected malformed current version to fail.")
    } catch let error as ToolingFailure {
      #expect(error.code == .modelCurrentVersionInvalid)
    }
  }

  @Test("xcdatamodeld rejects current version that points to missing model")
  func missingCurrentVersionTargetThrows() throws {
    let packageURL = try makeVersionedModelPackage(
      versions: ["V1.xcdatamodel"],
      currentVersion: "V2.xcdatamodel"
    )

    do {
      _ = try ToolingModelLoader.resolveModelInput(
        modelPath: packageURL.path,
        modelVersion: nil
      )
      Issue.record("Expected invalid current version target to fail.")
    } catch let error as ToolingFailure {
      #expect(error.code == .modelCurrentVersionInvalid)
    }
  }

  @Test("xcdatamodeld falls back to latest version when xccurrentversion is missing")
  func latestVersionFallbackIsUsed() throws {
    let packageURL = try makeVersionedModelPackage(
      versions: ["Model 2.xcdatamodel", "Model 10.xcdatamodel"],
      currentVersion: nil
    )

    let resolved = try ToolingModelLoader.resolveModelInput(
      modelPath: packageURL.path,
      modelVersion: nil
    )

    #expect(resolved.selectedVersionName == "Model 10.xcdatamodel")
  }

  @Test("missing explicit version throws modelVersionNotFound")
  func missingExplicitVersionThrows() throws {
    let packageURL = try makeVersionedModelPackage(
      versions: ["V1.xcdatamodel"],
      currentVersion: nil
    )

    do {
      _ = try ToolingModelLoader.resolveModelInput(
        modelPath: packageURL.path,
        modelVersion: "V2"
      )
      Issue.record("Expected explicit version lookup to fail.")
    } catch let error as ToolingFailure {
      #expect(error.code == .modelVersionNotFound)
    }
  }

  @Test("unsupported model extension throws modelUnsupported")
  func unsupportedExtensionThrows() throws {
    let directoryURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    let fileURL = directoryURL.appendingPathComponent("Schema.json")
    try Data("{}".utf8).write(to: fileURL)

    do {
      _ = try ToolingModelLoader.resolveModelInput(
        modelPath: fileURL.path,
        modelVersion: nil
      )
      Issue.record("Expected unsupported extension to fail.")
    } catch let error as ToolingFailure {
      #expect(error.code == .modelUnsupported)
    }
  }

  @Test("preferred momc path is used when executable exists")
  func preferredMomcPathIsUsed() throws {
    let executableURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathComponent("momc")
    try FileManager.default.createDirectory(
      at: executableURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try Data("#!/bin/sh\nexit 0\n".utf8).write(to: executableURL)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o755],
      ofItemAtPath: executableURL.path
    )

    let resolved = try ToolingModelLoader.discoverMomcBinary(
      preferredPath: executableURL.path
    )

    #expect(resolved.path == executableURL.path)
  }

  @Test("loader compiles and loads the integration model")
  func loaderCompilesAndLoadsRealModel() throws {
    let repositoryRoot = try findRepositoryRoot()
    let modelPath =
      repositoryRoot
      .appendingPathComponent("Models")
      .appendingPathComponent("Integration")
      .appendingPathComponent("CoreDataEvolutionIntegrationModel.xcdatamodeld")

    let loaded = try ToolingModelLoader.loadModel(
      modelPath: modelPath.path,
      modelVersion: nil
    )

    #expect(loaded.resolvedInput.kind == .xcdatamodeld)
    #expect(
      loaded.resolvedInput.selectedVersionName == "CoreDataEvolutionIntegrationModel.xcdatamodel")
    #expect(loaded.model.entitiesByName["CDEItem"] != nil)
    #expect(loaded.model.entitiesByName["CDETag"] != nil)
  }

  @Test("temporary compiled artifacts are cleaned up with loaded model lifetime")
  func temporaryCompiledArtifactsAreCleanedUp() throws {
    let repositoryRoot = try findRepositoryRoot()
    let modelPath =
      repositoryRoot
      .appendingPathComponent("Models")
      .appendingPathComponent("Integration")
      .appendingPathComponent("CoreDataEvolutionIntegrationModel.xcdatamodeld")

    var loaded: ToolingLoadedModel? = try ToolingModelLoader.loadModel(
      modelPath: modelPath.path,
      modelVersion: nil
    )
    let compileRootURL = try #require(
      loaded?.resolvedInput.compiledModelURL.deletingLastPathComponent())

    #expect(FileManager.default.fileExists(atPath: compileRootURL.path))

    loaded = nil

    #expect(FileManager.default.fileExists(atPath: compileRootURL.path) == false)
  }

  private func makeVersionedModelPackage(
    versions: [String],
    currentVersion: String?
  ) throws -> URL {
    let packageURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathComponent("Sample.xcdatamodeld")
    try FileManager.default.createDirectory(
      at: packageURL,
      withIntermediateDirectories: true
    )

    for version in versions {
      let versionURL = packageURL.appendingPathComponent(version)
      try FileManager.default.createDirectory(
        at: versionURL,
        withIntermediateDirectories: true
      )
    }

    if let currentVersion {
      let plist: [String: Any] = [
        "_XCCurrentVersionName": currentVersion
      ]
      let data = try PropertyListSerialization.data(
        fromPropertyList: plist,
        format: .xml,
        options: 0
      )
      try data.write(to: packageURL.appendingPathComponent(".xccurrentversion"))
    }

    return packageURL
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
