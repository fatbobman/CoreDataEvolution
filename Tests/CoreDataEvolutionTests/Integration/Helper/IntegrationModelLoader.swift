//
//  ------------------------------------------------
//  Original project: CoreDataEvolution
//  Created on 2026/3/5 by Fatbobman(东坡肘子)
//  X: @fatbobman
//  Mastodon: @fatbobman@mastodon.social
//  GitHub: @fatbobman
//  Blog: https://fatbobman.com
//  ------------------------------------------------
//  Copyright © 2024-present Fatbobman. All rights reserved.

@preconcurrency import CoreData
import Foundation

enum IntegrationModelLoaderError: Error, CustomStringConvertible {
  case repositoryRootNotFound
  case modelPathNotFound(String)
  case scriptNotFound(String)
  case compileFailed(status: Int32, output: String)
  case modelLoadFailed(String)

  var description: String {
    switch self {
    case .repositoryRootNotFound:
      return "Unable to locate repository root (Package.swift not found)."
    case .modelPathNotFound(let path):
      return "Compiled model path not found: \(path)"
    case .scriptNotFound(let path):
      return "Compile script not found: \(path)"
    case .compileFailed(let status, let output):
      return "Model compile failed with status \(status). Output:\n\(output)"
    case .modelLoadFailed(let path):
      return "Unable to load NSManagedObjectModel from: \(path)"
    }
  }
}

enum IntegrationModelLoader {
  static let modelName = "CoreDataEvolutionIntegrationModel"

  static func loadModel() throws -> NSManagedObjectModel {
    let momdURL = try resolveCompiledModelURL()
    guard let model = NSManagedObjectModel(contentsOf: momdURL) else {
      throw IntegrationModelLoaderError.modelLoadFailed(momdURL.path)
    }
    return model
  }

  static func resolveCompiledModelURL() throws -> URL {
    if let envPath = ProcessInfo.processInfo.environment["CDE_INTEGRATION_MODEL_MOMD"],
      envPath.isEmpty == false
    {
      let url = URL(filePath: envPath)
      guard FileManager.default.fileExists(atPath: url.path) else {
        throw IntegrationModelLoaderError.modelPathNotFound(url.path)
      }
      return url
    }

    let repositoryRoot = try findRepositoryRoot()
    let defaultOutputURL = compiledModelOutputURL(repositoryRoot: repositoryRoot)
    if FileManager.default.fileExists(atPath: defaultOutputURL.path),
      try compiledModelIsCurrent(
        repositoryRoot: repositoryRoot,
        compiledModelURL: defaultOutputURL
      )
    {
      return defaultOutputURL
    }

    try compileModel(repositoryRoot: repositoryRoot)
    guard FileManager.default.fileExists(atPath: defaultOutputURL.path) else {
      throw IntegrationModelLoaderError.modelPathNotFound(defaultOutputURL.path)
    }
    return defaultOutputURL
  }

  private static func compiledModelOutputURL(repositoryRoot: URL) -> URL {
    if let custom = ProcessInfo.processInfo.environment["CDE_INTEGRATION_MODEL_OUTPUT"],
      custom.isEmpty == false
    {
      return URL(filePath: custom)
    }
    return
      repositoryRoot
      .appendingPathComponent(".build")
      .appendingPathComponent("cde-models")
      .appendingPathComponent("\(modelName).momd")
  }

  private static func sourceModelURL(repositoryRoot: URL) -> URL {
    if let custom = ProcessInfo.processInfo.environment["CDE_INTEGRATION_MODEL_SOURCE"],
      custom.isEmpty == false
    {
      return URL(filePath: custom)
    }

    return
      repositoryRoot
      .appendingPathComponent("Models")
      .appendingPathComponent("Integration")
      .appendingPathComponent("\(modelName).xcdatamodeld")
  }

  private static func compiledModelIsCurrent(
    repositoryRoot: URL,
    compiledModelURL: URL
  ) throws -> Bool {
    let sourceURL = sourceModelURL(repositoryRoot: repositoryRoot)
    let sourceDate = try newestModificationDate(in: sourceURL)
    let compiledDate = try newestModificationDate(in: compiledModelURL)
    return compiledDate >= sourceDate
  }

  private static func newestModificationDate(in url: URL) throws -> Date {
    let resourceKeys: Set<URLResourceKey> = [.contentModificationDateKey, .isDirectoryKey]
    var newestDate =
      try url.resourceValues(forKeys: resourceKeys).contentModificationDate ?? .distantPast

    if (try url.resourceValues(forKeys: resourceKeys).isDirectory) == true {
      let enumerator = FileManager.default.enumerator(
        at: url,
        includingPropertiesForKeys: Array(resourceKeys)
      )

      while let childURL = enumerator?.nextObject() as? URL {
        let values = try childURL.resourceValues(forKeys: resourceKeys)
        if let modificationDate = values.contentModificationDate, modificationDate > newestDate {
          newestDate = modificationDate
        }
      }
    }

    return newestDate
  }

  private static func compileModel(repositoryRoot: URL) throws {
    let scriptURL =
      repositoryRoot
      .appendingPathComponent("Scripts")
      .appendingPathComponent("compile-integration-model.sh")
    guard FileManager.default.fileExists(atPath: scriptURL.path) else {
      throw IntegrationModelLoaderError.scriptNotFound(scriptURL.path)
    }

    let process = Process()
    process.executableURL = URL(filePath: "/usr/bin/env")
    process.arguments = ["bash", scriptURL.path]
    process.currentDirectoryURL = repositoryRoot
    process.environment = ProcessInfo.processInfo.environment

    let outputPipe = Pipe()
    process.standardOutput = outputPipe
    process.standardError = outputPipe

    try process.run()
    process.waitUntilExit()

    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: outputData, encoding: .utf8) ?? ""
    if process.terminationStatus != 0 {
      throw IntegrationModelLoaderError.compileFailed(
        status: process.terminationStatus,
        output: output
      )
    }
  }

  private static func findRepositoryRoot(filePath: String = #filePath) throws -> URL {
    var currentURL = URL(filePath: filePath).deletingLastPathComponent()
    while currentURL.path != "/" {
      let packageURL = currentURL.appendingPathComponent("Package.swift")
      if FileManager.default.fileExists(atPath: packageURL.path) {
        return currentURL
      }
      currentURL = currentURL.deletingLastPathComponent()
    }
    throw IntegrationModelLoaderError.repositoryRootNotFound
  }
}

final class IntegrationModelStack {
  static let model: NSManagedObjectModel = {
    do {
      return try IntegrationModelLoader.loadModel()
    } catch {
      preconditionFailure("Failed to load integration Core Data model: \(error)")
    }
  }()

  let container: NSPersistentContainer

  init(
    testName: String = "",
    fileID: String = #fileID,
    function: String = #function
  ) throws {
    container = try NSPersistentContainer.makeTest(
      model: Self.model,
      testName: testName,
      fileID: fileID,
      function: function
    )
    container.viewContext.automaticallyMergesChangesFromParent = true
  }
}
