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

public enum ToolingConfigTemplatePreset: String, Codable, Sendable {
  case minimal
  case full
}

public struct ToolingConfigTemplate: Codable, Sendable {
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

public struct GenerateTemplate: Codable, Sendable {
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

public struct ValidateTemplate: Codable, Sendable {
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
      schemaVersion: 1,
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
      schemaVersion: 1,
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
