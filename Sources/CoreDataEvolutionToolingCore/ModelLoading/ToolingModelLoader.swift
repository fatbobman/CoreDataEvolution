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

/// Bundles the loaded Core Data model with the resolution metadata that produced it.
public struct ToolingLoadedModel {
  public let model: NSManagedObjectModel
  public let resolvedInput: ToolingResolvedModelInput
  let temporaryArtifactToken: ToolingTemporaryArtifactToken?

  public init(
    model: NSManagedObjectModel,
    resolvedInput: ToolingResolvedModelInput,
    temporaryArtifactToken: ToolingTemporaryArtifactToken? = nil
  ) {
    self.model = model
    self.resolvedInput = resolvedInput
    self.temporaryArtifactToken = temporaryArtifactToken
  }
}

/// Loads Core Data models from source packages (`.xcdatamodeld`, `.xcdatamodel`) or compiled
/// artifacts (`.momd`, `.mom`).
///
/// Notes:
/// - Source models are compiled through `momc` into a temporary location.
/// - `.xccurrentversion` is treated as the authoritative current version for `.xcdatamodeld`.
public enum ToolingModelLoader {
  /// Resolves the user's input path into a concrete source/compiled pair without loading Core Data.
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

  /// Finds `momc` using the same precedence as the repository scripts:
  /// explicit path -> `xcrun --find momc` -> `PATH`.
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

  /// End-to-end entry point used by services that need a real `NSManagedObjectModel`.
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
      let temporaryArtifactsRootURL = resolvedInput.compiledModelURL.deletingLastPathComponent()
      do {
        try compileModel(
          sourceURL: resolvedInput.selectedSourceURL,
          outputURL: resolvedInput.compiledModelURL,
          momcURL: momcURL
        )
        return try loadCompiledModel(
          from: resolvedInput,
          temporaryArtifactToken: .init(rootURL: temporaryArtifactsRootURL)
        )
      } catch {
        try? FileManager.default.removeItem(at: temporaryArtifactsRootURL)
        throw error
      }
    }
  }

  /// Source-model-only entry point used by generate/bootstrap/inspect/validate.
  ///
  /// This resolves the source model once, enforces the source-only/codegen contract, then compiles
  /// and loads the selected version.
  public static func loadValidatedSourceModel(
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
      throw ToolingFailure.user(
        .modelUnsupported,
        "tooling commands require a source model path. Use .xcdatamodeld or .xcdatamodel instead of '\(resolvedInput.originalURL.path)'."
      )
    case .xcdatamodeld, .xcdatamodel:
      try validateSourceModelCodeGeneration(selectedSourceURL: resolvedInput.selectedSourceURL)
      let momcURL = try discoverMomcBinary(preferredPath: momcBin)
      let temporaryArtifactsRootURL = resolvedInput.compiledModelURL.deletingLastPathComponent()
      do {
        try compileModel(
          sourceURL: resolvedInput.selectedSourceURL,
          outputURL: resolvedInput.compiledModelURL,
          momcURL: momcURL
        )
        return try loadCompiledModel(
          from: resolvedInput,
          temporaryArtifactToken: .init(rootURL: temporaryArtifactsRootURL)
        )
      } catch {
        try? FileManager.default.removeItem(at: temporaryArtifactsRootURL)
        throw error
      }
    }
  }

  /// Validates the repository's source-model input contract before the expensive load path begins.
  ///
  /// Tooling commands are intentionally source-model-only. They reject compiled `.mom` / `.momd`
  /// inputs and any source entity that still opts into Xcode-managed class/module generation.
  public static func validateSourceModelLayout(
    modelPath: String,
    modelVersion: String?
  ) throws {
    let resolvedInput = try resolveModelInput(
      modelPath: modelPath,
      modelVersion: modelVersion
    )

    switch resolvedInput.kind {
    case .xcdatamodeld, .xcdatamodel:
      try validateSourceModelCodeGeneration(selectedSourceURL: resolvedInput.selectedSourceURL)
    case .momd, .mom:
      throw ToolingFailure.user(
        .modelUnsupported,
        "tooling commands require a source model path. Use .xcdatamodeld or .xcdatamodel instead of '\(resolvedInput.originalURL.path)'."
      )
    }
  }

  // Loading is split from path resolution so tests can validate version-selection behavior
  // without requiring a working Core Data toolchain.
  private static func loadCompiledModel(
    from resolvedInput: ToolingResolvedModelInput,
    temporaryArtifactToken: ToolingTemporaryArtifactToken? = nil
  ) throws -> ToolingLoadedModel {
    guard let model = NSManagedObjectModel(contentsOf: resolvedInput.compiledModelURL) else {
      throw ToolingFailure.runtime(
        .modelLoadFailed,
        "failed to load NSManagedObjectModel from '\(resolvedInput.compiledModelURL.path)'."
      )
    }

    return .init(
      model: model,
      resolvedInput: resolvedInput,
      temporaryArtifactToken: temporaryArtifactToken
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

    let data: Data
    let plist: Any
    do {
      data = try Data(contentsOf: currentVersionFile)
      plist = try PropertyListSerialization.propertyList(from: data, format: nil)
    } catch {
      throw ToolingFailure.user(
        .modelCurrentVersionInvalid,
        "failed to read '.xccurrentversion' in '\(packageURL.lastPathComponent)' (\(error.localizedDescription))."
      )
    }

    guard let dictionary = plist as? [String: Any],
      let currentName = dictionary["_XCCurrentVersionName"] as? String
    else {
      throw ToolingFailure.user(
        .modelCurrentVersionInvalid,
        "'.xccurrentversion' in '\(packageURL.lastPathComponent)' is malformed."
      )
    }

    guard let versionURL = availableVersions.first(where: { $0.lastPathComponent == currentName })
    else {
      throw ToolingFailure.user(
        .modelCurrentVersionInvalid,
        "'.xccurrentversion' in '\(packageURL.lastPathComponent)' points to missing version '\(currentName)'."
      )
    }

    return versionURL
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

  /// Enforces the repository convention that source models must not opt into Xcode codegen.
  ///
  /// Tooling-generated macro code will conflict with Xcode-managed Core Data class generation, so
  /// source models using `class` / `module` / `category` code generation are rejected before
  /// compilation. Xcode's "Manual/None" mode is serialized by omitting the attribute entirely, so
  /// missing `codeGenerationType` is treated as valid.
  private static func validateSourceModelCodeGeneration(selectedSourceURL: URL) throws {
    let contentsURL = selectedSourceURL.appendingPathComponent("contents")
    guard FileManager.default.fileExists(atPath: contentsURL.path) else { return }

    let contents: String
    do {
      contents = try String(contentsOf: contentsURL, encoding: .utf8)
    } catch {
      throw ToolingFailure.runtime(
        .ioFailed,
        "failed to read source model contents at '\(contentsURL.path)' (\(error.localizedDescription))."
      )
    }

    let pattern = #"<entity\b[^>]*\bname="([^"]+)"([^>]*)>"#
    let regex = try! NSRegularExpression(pattern: pattern)
    let codegenRegex = try! NSRegularExpression(pattern: #"\bcodeGenerationType="([^"]+)""#)
    let range = NSRange(contents.startIndex..<contents.endIndex, in: contents)

    for match in regex.matches(in: contents, range: range) {
      guard
        let nameRange = Range(match.range(at: 1), in: contents),
        let attributesRange = Range(match.range(at: 2), in: contents)
      else {
        continue
      }

      let entityName = String(contents[nameRange])
      let attributes = String(contents[attributesRange])
      let attributesNSRange = NSRange(attributes.startIndex..<attributes.endIndex, in: attributes)
      guard let codegenMatch = codegenRegex.firstMatch(in: attributes, range: attributesNSRange),
        let codegenRange = Range(codegenMatch.range(at: 1), in: attributes)
      else {
        continue
      }

      let codeGenerationType = String(attributes[codegenRange])
      guard ["class", "module", "category"].contains(codeGenerationType.lowercased()) else {
        continue
      }

      throw ToolingFailure.user(
        .configInvalid,
        """
        source model entity '\(entityName)' must not use Xcode code generation mode \
        '\(codeGenerationType)' before running tooling.
        """,
        hint:
          "Set the Core Data model entity Codegen to Manual/None so the model omits codeGenerationType and avoids conflicts with tooling-generated macro code."
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
