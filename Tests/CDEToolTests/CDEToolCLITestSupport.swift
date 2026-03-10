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

struct CDEToolRunResult {
  let exitCode: Int32
  let stdout: String
  let stderr: String
}

func runTool(
  _ arguments: [String],
  currentDirectoryURL: URL? = nil,
  filePath: String = #filePath
) throws -> CDEToolRunResult {
  let process = Process()
  process.executableURL = try toolExecutableURL(filePath: filePath)
  process.arguments = arguments
  process.currentDirectoryURL = try currentDirectoryURL ?? repositoryRoot(filePath: filePath)

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
  return .init(
    exitCode: process.terminationStatus,
    stdout: stdout,
    stderr: stderr
  )
}

func repositoryRoot(filePath: String = #filePath) throws -> URL {
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

func toolExecutableURL(filePath: String = #filePath) throws -> URL {
  let buildDirectory = try repositoryRoot(filePath: filePath)
    .appendingPathComponent(".build", isDirectory: true)
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

func makeToolingSourceModelFixture(
  stripCodeGenerationType: Bool = true,
  filePath: String = #filePath
) throws -> URL {
  let sourcePackageURL =
    try repositoryRoot(filePath: filePath)
    .appendingPathComponent("Models")
    .appendingPathComponent("Integration")
    .appendingPathComponent("CoreDataEvolutionIntegrationModel.xcdatamodeld")

  let temporaryPackageURL = FileManager.default.temporaryDirectory
    .appendingPathComponent("CDEToolTests", isDirectory: true)
    .appendingPathComponent(UUID().uuidString, isDirectory: true)
    .appendingPathComponent("CoreDataEvolutionIntegrationModel.xcdatamodeld", isDirectory: true)

  try FileManager.default.createDirectory(
    at: temporaryPackageURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
  )
  try FileManager.default.copyItem(at: sourcePackageURL, to: temporaryPackageURL)

  guard stripCodeGenerationType else { return temporaryPackageURL }

  let contentsURL =
    temporaryPackageURL
    .appendingPathComponent("CoreDataEvolutionIntegrationModel.xcdatamodel")
    .appendingPathComponent("contents")
  var contents = try String(contentsOf: contentsURL, encoding: .utf8)
  contents = contents.replacingOccurrences(
    of: #"\s*codeGenerationType="[^"]+""#,
    with: "",
    options: .regularExpression
  )
  try contents.write(to: contentsURL, atomically: true, encoding: .utf8)

  return temporaryPackageURL
}

func makeMinimalSourceModelFixture(entityName: String = "Item") throws -> URL {
  let modelURL = FileManager.default.temporaryDirectory
    .appendingPathComponent("CDEToolTests", isDirectory: true)
    .appendingPathComponent(UUID().uuidString, isDirectory: true)
    .appendingPathComponent("Minimal.xcdatamodel", isDirectory: true)
  try FileManager.default.createDirectory(
    at: modelURL,
    withIntermediateDirectories: true
  )

  let contents = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <model type="com.apple.IDECoreDataModeler.DataModel" documentVersion="1.0" lastSavedToolsVersion="1" systemVersion="1" minimumToolsVersion="Automatic" sourceLanguage="Swift" userDefinedModelVersionIdentifier="">
        <entity name="\(entityName)" representedClassName="\(entityName)" syncable="YES">
            <attribute name="name" optional="YES" attributeType="String"/>
        </entity>
    </model>
    """
  try contents.write(
    to: modelURL.appendingPathComponent("contents"),
    atomically: true,
    encoding: .utf8
  )

  return modelURL
}

func makeGeneratedSourceFixture(filePath: String = #filePath) throws -> (
  modelPath: String, sourceDirectory: URL, cleanUp: () -> Void
) {
  let modelPath = try makeToolingSourceModelFixture(filePath: filePath).path
  let sourceDirectory = FileManager.default.temporaryDirectory
    .appendingPathComponent("CDEToolTests", isDirectory: true)
    .appendingPathComponent(UUID().uuidString, isDirectory: true)
  try FileManager.default.createDirectory(
    at: sourceDirectory,
    withIntermediateDirectories: true
  )

  let generateResult = try GenerateService.run(
    makeGenerateRequest(outputDirectory: sourceDirectory.path, modelPath: modelPath))
  for file in generateResult.filePlan {
    let outputURL = sourceDirectory.appendingPathComponent(file.relativePath)
    try FileManager.default.createDirectory(
      at: outputURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try file.contents.write(to: outputURL, atomically: true, encoding: .utf8)
  }

  return (
    modelPath,
    sourceDirectory,
    {
      try? FileManager.default.removeItem(at: sourceDirectory)
      try? FileManager.default.removeItem(
        at: URL(fileURLWithPath: modelPath).deletingLastPathComponent())
    }
  )
}

func makeGenerateRequest(outputDirectory: String, modelPath: String) -> GenerateRequest {
  .init(
    modelPath: modelPath,
    modelVersion: nil,
    momcBin: nil,
    outputDir: outputDirectory,
    moduleName: "AppModels",
    typeMappings: makeDefaultToolingTypeMappings(),
    attributeRules: makeIntegrationAttributeRules(),
    relationshipRules: .init(),
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

func makeIntegrationAttributeRules() -> ToolingAttributeRules {
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
          transformerName: "CDEStringListTransformer"
        ),
      ]
    ]
  )
}

func writeToolingConfig(
  _ template: ToolingConfigTemplate,
  fileName: String = "cde-tool.json"
) throws -> URL {
  let directory = FileManager.default.temporaryDirectory
    .appendingPathComponent("CDEToolTests", isDirectory: true)
    .appendingPathComponent(UUID().uuidString, isDirectory: true)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  let configURL = directory.appendingPathComponent(fileName)
  try encodeToolingJSON(template).write(to: configURL)
  return configURL
}

func makeRelativePath(from baseDirectory: URL, to targetURL: URL) -> String {
  let baseComponents = baseDirectory.standardizedFileURL.pathComponents
  let targetComponents = targetURL.standardizedFileURL.pathComponents
  let sharedCount = zip(baseComponents, targetComponents)
    .prefix { $0 == $1 }
    .count
  let relativeComponents =
    Array(repeating: "..", count: baseComponents.count - sharedCount)
    + targetComponents.dropFirst(sharedCount)

  guard relativeComponents.isEmpty == false else {
    return "."
  }

  return NSString.path(withComponents: relativeComponents)
}

func rewriteEntityFile(
  named fileName: String,
  in sourceDirectory: URL,
  transform: (String) -> String
) throws {
  let fileURL = sourceDirectory.appendingPathComponent(fileName)
  let contents = try String(contentsOf: fileURL, encoding: .utf8)
  try transform(contents).write(to: fileURL, atomically: true, encoding: .utf8)
}
