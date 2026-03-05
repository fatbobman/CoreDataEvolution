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

@preconcurrency import CoreData
import Foundation

public struct ToolingLoadedModel {
  public let model: NSManagedObjectModel
  public let resolvedInput: ToolingResolvedModelInput

  public init(
    model: NSManagedObjectModel,
    resolvedInput: ToolingResolvedModelInput
  ) {
    self.model = model
    self.resolvedInput = resolvedInput
  }
}

public enum ToolingModelLoader {
  public static func resolveModelInput(
    modelPath: String,
    modelVersion: String?
  ) throws -> ToolingResolvedModelInput {
    let originalURL = URL(fileURLWithPath: modelPath)
    guard FileManager.default.fileExists(atPath: originalURL.path) else {
      throw ToolingFailure.user(
        .modelNotFound,
        "model path not found: '\(originalURL.path)'."
      )
    }

    switch originalURL.pathExtension {
    case "xcdatamodeld":
      return try resolveVersionedModelPackage(
        packageURL: originalURL,
        explicitVersion: modelVersion
      )
    case "xcdatamodel":
      let compiledURL = makeCompiledOutputURL(
        for: originalURL,
        compiledExtension: "mom"
      )
      return .init(
        originalURL: originalURL,
        selectedSourceURL: originalURL,
        compiledModelURL: compiledURL,
        kind: .xcdatamodel,
        selectedVersionName: nil
      )
    case "momd":
      return .init(
        originalURL: originalURL,
        selectedSourceURL: originalURL,
        compiledModelURL: originalURL,
        kind: .momd,
        selectedVersionName: nil
      )
    case "mom":
      return .init(
        originalURL: originalURL,
        selectedSourceURL: originalURL,
        compiledModelURL: originalURL,
        kind: .mom,
        selectedVersionName: nil
      )
    default:
      throw ToolingFailure.user(
        .modelUnsupported,
        "unsupported model input: '\(originalURL.path)'. Expected .xcdatamodeld, .xcdatamodel, .momd, or .mom."
      )
    }
  }

  public static func discoverMomcBinary(
    preferredPath: String? = nil
  ) throws -> URL {
    if let preferredPath, preferredPath.isEmpty == false {
      let url = URL(fileURLWithPath: preferredPath)
      guard FileManager.default.isExecutableFile(atPath: url.path) else {
        throw ToolingFailure.user(
          .momcNotFound,
          "momc binary is not executable at '\(url.path)'."
        )
      }
      return url
    }

    if let xcrunURL = searchExecutable(named: "xcrun"),
      let resolved = try resolveMomcViaXcrun(xcrunURL: xcrunURL)
    {
      return resolved
    }

    if let pathURL = searchExecutable(named: "momc") {
      return pathURL
    }

    throw ToolingFailure.user(
      .momcNotFound,
      "unable to locate 'momc'. Pass --momc-bin or install Xcode command line tools."
    )
  }

  public static func loadModel(
    modelPath: String,
    modelVersion: String?,
    momcBin: String? = nil
  ) throws -> ToolingLoadedModel {
    let resolvedInput = try resolveModelInput(
      modelPath: modelPath,
      modelVersion: modelVersion
    )

    switch resolvedInput.kind {
    case .momd, .mom:
      return try loadCompiledModel(from: resolvedInput)
    case .xcdatamodeld, .xcdatamodel:
      let momcURL = try discoverMomcBinary(preferredPath: momcBin)
      try compileModel(
        sourceURL: resolvedInput.selectedSourceURL,
        outputURL: resolvedInput.compiledModelURL,
        momcURL: momcURL
      )
      return try loadCompiledModel(from: resolvedInput)
    }
  }

  private static func loadCompiledModel(
    from resolvedInput: ToolingResolvedModelInput
  ) throws -> ToolingLoadedModel {
    guard let model = NSManagedObjectModel(contentsOf: resolvedInput.compiledModelURL) else {
      throw ToolingFailure.runtime(
        .modelLoadFailed,
        "failed to load NSManagedObjectModel from '\(resolvedInput.compiledModelURL.path)'."
      )
    }

    return .init(
      model: model,
      resolvedInput: resolvedInput
    )
  }

  private static func resolveVersionedModelPackage(
    packageURL: URL,
    explicitVersion: String?
  ) throws -> ToolingResolvedModelInput {
    let selectedVersionURL = try selectModelVersion(
      in: packageURL,
      explicitVersion: explicitVersion
    )
    let compiledURL = makeCompiledOutputURL(
      for: packageURL,
      compiledExtension: "momd"
    )
    return .init(
      originalURL: packageURL,
      selectedSourceURL: selectedVersionURL,
      compiledModelURL: compiledURL,
      kind: .xcdatamodeld,
      selectedVersionName: selectedVersionURL.lastPathComponent
    )
  }

  private static func selectModelVersion(
    in packageURL: URL,
    explicitVersion: String?
  ) throws -> URL {
    let versionURLs = try modelVersionURLs(in: packageURL)
    guard versionURLs.isEmpty == false else {
      throw ToolingFailure.user(
        .modelNotFound,
        "no .xcdatamodel versions found in '\(packageURL.path)'."
      )
    }

    if let explicitVersion, explicitVersion.isEmpty == false {
      let candidateName =
        explicitVersion.hasSuffix(".xcdatamodel")
        ? explicitVersion : "\(explicitVersion).xcdatamodel"
      if let match = versionURLs.first(where: { $0.lastPathComponent == candidateName }) {
        return match
      }
      throw ToolingFailure.user(
        .modelVersionNotFound,
        "model version '\(explicitVersion)' not found in '\(packageURL.lastPathComponent)'."
      )
    }

    if let currentVersionURL = try currentVersionURL(in: packageURL, availableVersions: versionURLs)
    {
      return currentVersionURL
    }

    return versionURLs.sorted {
      $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
    }.last!
  }

  private static func modelVersionURLs(in packageURL: URL) throws -> [URL] {
    let contents = try FileManager.default.contentsOfDirectory(
      at: packageURL,
      includingPropertiesForKeys: nil
    )
    return contents.filter { $0.pathExtension == "xcdatamodel" }
  }

  private static func currentVersionURL(
    in packageURL: URL,
    availableVersions: [URL]
  ) throws -> URL? {
    let currentVersionFile = packageURL.appendingPathComponent(".xccurrentversion")
    guard FileManager.default.fileExists(atPath: currentVersionFile.path) else {
      return nil
    }

    let data = try Data(contentsOf: currentVersionFile)
    let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
    guard let dictionary = plist as? [String: Any],
      let currentName = dictionary["_XCCurrentVersionName"] as? String
    else {
      return nil
    }

    return availableVersions.first { $0.lastPathComponent == currentName }
  }

  private static func makeCompiledOutputURL(
    for sourceURL: URL,
    compiledExtension: String
  ) -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent("CoreDataEvolutionToolingCore")
      .appendingPathComponent(UUID().uuidString)
      .appendingPathComponent(
        "\(sourceURL.deletingPathExtension().lastPathComponent).\(compiledExtension)")
  }

  private static func compileModel(
    sourceURL: URL,
    outputURL: URL,
    momcURL: URL
  ) throws {
    try FileManager.default.createDirectory(
      at: outputURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )

    let process = Process()
    process.executableURL = momcURL
    process.arguments = [sourceURL.path, outputURL.path]

    let outputPipe = Pipe()
    process.standardOutput = outputPipe
    process.standardError = outputPipe

    do {
      try process.run()
      process.waitUntilExit()
    } catch {
      throw ToolingFailure.runtime(
        .modelCompileFailed,
        "failed to run momc at '\(momcURL.path)' (\(error.localizedDescription))."
      )
    }

    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: outputData, encoding: .utf8) ?? ""

    guard process.terminationStatus == 0 else {
      throw ToolingFailure.runtime(
        .modelCompileFailed,
        "momc failed to compile model '\(sourceURL.path)' (status \(process.terminationStatus)).",
        hint: output.isEmpty ? nil : output
      )
    }
  }

  private static func resolveMomcViaXcrun(xcrunURL: URL) throws -> URL? {
    let process = Process()
    process.executableURL = xcrunURL
    process.arguments = ["--find", "momc"]

    let outputPipe = Pipe()
    process.standardOutput = outputPipe
    process.standardError = outputPipe

    do {
      try process.run()
      process.waitUntilExit()
    } catch {
      return nil
    }

    guard process.terminationStatus == 0 else {
      return nil
    }

    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
    guard
      let output = String(data: outputData, encoding: .utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines),
      output.isEmpty == false
    else {
      return nil
    }

    let resolvedURL = URL(fileURLWithPath: output)
    return FileManager.default.isExecutableFile(atPath: resolvedURL.path) ? resolvedURL : nil
  }

  private static func searchExecutable(named name: String) -> URL? {
    let pathValue = ProcessInfo.processInfo.environment["PATH"] ?? ""
    for component in pathValue.split(separator: ":") {
      let candidate = URL(fileURLWithPath: String(component)).appendingPathComponent(name)
      if FileManager.default.isExecutableFile(atPath: candidate.path) {
        return candidate
      }
    }
    return nil
  }
}
