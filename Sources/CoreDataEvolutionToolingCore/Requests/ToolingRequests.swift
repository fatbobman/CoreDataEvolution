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

public struct InitConfigRequest: Sendable, Equatable {
  public let preset: ToolingConfigTemplatePreset

  public init(preset: ToolingConfigTemplatePreset) {
    self.preset = preset
  }
}

public struct GenerateRequest: Sendable, Equatable {
  public let modelPath: String
  public let modelVersion: String?
  public let momcBin: String?
  public let outputDir: String
  public let moduleName: String
  public let accessLevel: String
  public let singleFile: Bool
  public let splitByEntity: Bool
  public let overwrite: String
  public let cleanStale: Bool
  public let dryRun: Bool
  public let format: String
  public let headerTemplate: String?
  public let generateInit: Bool
  public let relationshipSetterPolicy: String
  public let relationshipCountPolicy: String
  public let defaultDecodeFailurePolicy: String

  public init(
    modelPath: String,
    modelVersion: String?,
    momcBin: String?,
    outputDir: String,
    moduleName: String,
    accessLevel: String,
    singleFile: Bool,
    splitByEntity: Bool,
    overwrite: String,
    cleanStale: Bool,
    dryRun: Bool,
    format: String,
    headerTemplate: String?,
    generateInit: Bool,
    relationshipSetterPolicy: String,
    relationshipCountPolicy: String,
    defaultDecodeFailurePolicy: String
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

public struct ValidateRequest: Sendable, Equatable {
  public let modelPath: String
  public let modelVersion: String?
  public let sourceDir: String
  public let moduleName: String
  public let include: [String]
  public let exclude: [String]
  public let level: String
  public let report: String
  public let failOnWarning: Bool
  public let maxIssues: Int

  public init(
    modelPath: String,
    modelVersion: String?,
    sourceDir: String,
    moduleName: String,
    include: [String],
    exclude: [String],
    level: String,
    report: String,
    failOnWarning: Bool,
    maxIssues: Int
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

public struct InspectRequest: Sendable, Equatable {
  public let modelPath: String
  public let modelVersion: String?

  public init(modelPath: String, modelVersion: String?) {
    self.modelPath = modelPath
    self.modelVersion = modelVersion
  }
}

public struct GenerateRequestOverrides: Sendable, Equatable {
  public var modelPath: String?
  public var modelVersion: String?
  public var momcBin: String?
  public var outputDir: String?
  public var moduleName: String?
  public var accessLevel: String?
  public var singleFile: Bool?
  public var splitByEntity: Bool?
  public var overwrite: String?
  public var cleanStale: Bool?
  public var dryRun: Bool?
  public var format: String?
  public var headerTemplate: String?
  public var generateInit: Bool?
  public var relationshipSetterPolicy: String?
  public var relationshipCountPolicy: String?
  public var defaultDecodeFailurePolicy: String?

  public init() {}
}

public struct ValidateRequestOverrides: Sendable, Equatable {
  public var modelPath: String?
  public var modelVersion: String?
  public var sourceDir: String?
  public var moduleName: String?
  public var include: [String]?
  public var exclude: [String]?
  public var level: String?
  public var report: String?
  public var failOnWarning: Bool?
  public var maxIssues: Int?

  public init() {}
}
