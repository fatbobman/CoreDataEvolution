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

import Foundation

public let toolingSupportedSchemaVersion = 1

public enum ToolingConfigTemplatePreset: String, Codable, Sendable {
  case minimal
  case full
}

public struct ToolingConfigTemplate: Codable, Sendable, Equatable {
  public let schemaVersion: Int
  public let generate: GenerateTemplate?
  public let validate: ValidateTemplate?

  public init(
    schemaVersion: Int,
    generate: GenerateTemplate?,
    validate: ValidateTemplate?
  ) {
    self.schemaVersion = schemaVersion
    self.generate = generate
    self.validate = validate
  }

  enum CodingKeys: String, CodingKey {
    case schemaVersion = "$schemaVersion"
    case generate
    case validate
  }
}

public struct GenerateTemplate: Codable, Sendable, Equatable {
  public let modelPath: String
  public let modelVersion: String?
  public let momcBin: String?
  public let outputDir: String
  public let moduleName: String
  public let accessLevel: String?
  public let singleFile: Bool?
  public let splitByEntity: Bool?
  public let overwrite: String?
  public let cleanStale: Bool?
  public let dryRun: Bool?
  public let format: String?
  public let headerTemplate: String?
  public let generateInit: Bool?
  public let relationshipSetterPolicy: String?
  public let relationshipCountPolicy: String?
  public let defaultDecodeFailurePolicy: String?

  public init(
    modelPath: String,
    modelVersion: String?,
    momcBin: String?,
    outputDir: String,
    moduleName: String,
    accessLevel: String?,
    singleFile: Bool?,
    splitByEntity: Bool?,
    overwrite: String?,
    cleanStale: Bool?,
    dryRun: Bool?,
    format: String?,
    headerTemplate: String?,
    generateInit: Bool?,
    relationshipSetterPolicy: String?,
    relationshipCountPolicy: String?,
    defaultDecodeFailurePolicy: String?
  ) {
    self.modelPath = modelPath
    self.modelVersion = modelVersion
    self.momcBin = momcBin
    self.outputDir = outputDir
    self.moduleName = moduleName
    self.accessLevel = accessLevel
    self.singleFile = singleFile
    self.splitByEntity = splitByEntity
    self.overwrite = overwrite
    self.cleanStale = cleanStale
    self.dryRun = dryRun
    self.format = format
    self.headerTemplate = headerTemplate
    self.generateInit = generateInit
    self.relationshipSetterPolicy = relationshipSetterPolicy
    self.relationshipCountPolicy = relationshipCountPolicy
    self.defaultDecodeFailurePolicy = defaultDecodeFailurePolicy
  }
}

public struct ValidateTemplate: Codable, Sendable, Equatable {
  public let modelPath: String
  public let modelVersion: String?
  public let sourceDir: String
  public let moduleName: String
  public let include: [String]?
  public let exclude: [String]?
  public let level: String?
  public let report: String?
  public let failOnWarning: Bool?
  public let maxIssues: Int?

  public init(
    modelPath: String,
    modelVersion: String?,
    sourceDir: String,
    moduleName: String,
    include: [String]?,
    exclude: [String]?,
    level: String?,
    report: String?,
    failOnWarning: Bool?,
    maxIssues: Int?
  ) {
    self.modelPath = modelPath
    self.modelVersion = modelVersion
    self.sourceDir = sourceDir
    self.moduleName = moduleName
    self.include = include
    self.exclude = exclude
    self.level = level
    self.report = report
    self.failOnWarning = failOnWarning
    self.maxIssues = maxIssues
  }
}

public func makeDefaultConfigTemplate(preset: ToolingConfigTemplatePreset) -> ToolingConfigTemplate
{
  switch preset {
  case .minimal:
    return .init(
      schemaVersion: toolingSupportedSchemaVersion,
      generate: .init(
        modelPath: "Models/AppModel.xcdatamodeld",
        modelVersion: nil,
        momcBin: nil,
        outputDir: "Generated/CoreDataEvolution",
        moduleName: "AppModels",
        accessLevel: nil,
        singleFile: nil,
        splitByEntity: nil,
        overwrite: nil,
        cleanStale: nil,
        dryRun: nil,
        format: nil,
        headerTemplate: nil,
        generateInit: nil,
        relationshipSetterPolicy: nil,
        relationshipCountPolicy: nil,
        defaultDecodeFailurePolicy: nil
      ),
      validate: .init(
        modelPath: "Models/AppModel.xcdatamodeld",
        modelVersion: nil,
        sourceDir: "Sources/AppModels",
        moduleName: "AppModels",
        include: nil,
        exclude: nil,
        level: nil,
        report: nil,
        failOnWarning: nil,
        maxIssues: nil
      )
    )
  case .full:
    return .init(
      schemaVersion: toolingSupportedSchemaVersion,
      generate: .init(
        modelPath: "Models/AppModel.xcdatamodeld",
        modelVersion: nil,
        momcBin: nil,
        outputDir: "Generated/CoreDataEvolution",
        moduleName: "AppModels",
        accessLevel: "internal",
        singleFile: false,
        splitByEntity: true,
        overwrite: "none",
        cleanStale: false,
        dryRun: false,
        format: "swift-format",
        headerTemplate: nil,
        generateInit: false,
        relationshipSetterPolicy: "warning",
        relationshipCountPolicy: "none",
        defaultDecodeFailurePolicy: "fallbackToDefaultValue"
      ),
      validate: .init(
        modelPath: "Models/AppModel.xcdatamodeld",
        modelVersion: nil,
        sourceDir: "Sources/AppModels",
        moduleName: "AppModels",
        include: [],
        exclude: [],
        level: "quick",
        report: "text",
        failOnWarning: false,
        maxIssues: 200
      )
    )
  }
}

public func encodeToolingJSON<T: Encodable>(_ value: T) throws -> Data {
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
  return try encoder.encode(value)
}

private struct ToolingConfigSchemaEnvelope: Decodable {
  let schemaVersion: Int?

  enum CodingKeys: String, CodingKey {
    case schemaVersion = "$schemaVersion"
  }
}

public func loadToolingConfigTemplate(from data: Data) throws -> ToolingConfigTemplate {
  let decoder = JSONDecoder()

  do {
    let envelope = try decoder.decode(ToolingConfigSchemaEnvelope.self, from: data)
    let schemaVersion = envelope.schemaVersion ?? toolingSupportedSchemaVersion
    guard schemaVersion <= toolingSupportedSchemaVersion else {
      throw ToolingFailure.user(
        .configSchemaUnsupported,
        "config schema version '\(schemaVersion)' is newer than supported '\(toolingSupportedSchemaVersion)'. Please upgrade cde-tool."
      )
    }
    return try decoder.decode(ToolingConfigTemplate.self, from: data)
  } catch let failure as ToolingFailure {
    throw failure
  } catch {
    throw ToolingFailure.runtime(
      .ioFailed,
      "failed to decode config file (\(error.localizedDescription))."
    )
  }
}

public func loadToolingConfigTemplate(at url: URL) throws -> ToolingConfigTemplate {
  do {
    let data = try Data(contentsOf: url)
    return try loadToolingConfigTemplate(from: data)
  } catch let failure as ToolingFailure {
    throw failure
  } catch {
    throw ToolingFailure.runtime(
      .ioFailed,
      "failed to read config file at '\(url.path)' (\(error.localizedDescription))."
    )
  }
}

extension GenerateRequest {
  public init(config: GenerateTemplate, overrides: GenerateRequestOverrides = .init()) {
    self.init(
      modelPath: overrides.modelPath ?? config.modelPath,
      modelVersion: overrides.modelVersion ?? config.modelVersion,
      momcBin: overrides.momcBin ?? config.momcBin,
      outputDir: overrides.outputDir ?? config.outputDir,
      moduleName: overrides.moduleName ?? config.moduleName,
      accessLevel: overrides.accessLevel ?? config.accessLevel ?? "internal",
      singleFile: overrides.singleFile ?? config.singleFile ?? false,
      splitByEntity: overrides.splitByEntity ?? config.splitByEntity ?? true,
      overwrite: overrides.overwrite ?? config.overwrite ?? "none",
      cleanStale: overrides.cleanStale ?? config.cleanStale ?? false,
      dryRun: overrides.dryRun ?? config.dryRun ?? false,
      format: overrides.format ?? config.format ?? "none",
      headerTemplate: overrides.headerTemplate ?? config.headerTemplate,
      generateInit: overrides.generateInit ?? config.generateInit ?? false,
      relationshipSetterPolicy: overrides.relationshipSetterPolicy
        ?? config.relationshipSetterPolicy ?? "warning",
      relationshipCountPolicy: overrides.relationshipCountPolicy
        ?? config.relationshipCountPolicy ?? "none",
      defaultDecodeFailurePolicy: overrides.defaultDecodeFailurePolicy
        ?? config.defaultDecodeFailurePolicy ?? "fallbackToDefaultValue"
    )
  }
}

extension ValidateRequest {
  public init(config: ValidateTemplate, overrides: ValidateRequestOverrides = .init()) {
    self.init(
      modelPath: overrides.modelPath ?? config.modelPath,
      modelVersion: overrides.modelVersion ?? config.modelVersion,
      sourceDir: overrides.sourceDir ?? config.sourceDir,
      moduleName: overrides.moduleName ?? config.moduleName,
      include: overrides.include ?? config.include ?? [],
      exclude: overrides.exclude ?? config.exclude ?? [],
      level: overrides.level ?? config.level ?? "quick",
      report: overrides.report ?? config.report ?? "text",
      failOnWarning: overrides.failOnWarning ?? config.failOnWarning ?? false,
      maxIssues: overrides.maxIssues ?? config.maxIssues ?? 200
    )
  }
}
