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

/// Request for emitting a static config template.
public struct InitConfigRequest: Sendable, Equatable {
  public let preset: ToolingConfigTemplatePreset

  public init(preset: ToolingConfigTemplatePreset) {
    self.preset = preset
  }
}

/// Request for generating a model-derived config scaffold.
public struct BootstrapConfigRequest: Sendable, Equatable {
  public let modelPath: String
  public let modelVersion: String?
  public let momcBin: String?
  public let moduleName: String
  public let outputDir: String
  public let sourceDir: String

  public init(
    modelPath: String,
    modelVersion: String?,
    momcBin: String?,
    moduleName: String,
    outputDir: String,
    sourceDir: String
  ) {
    self.modelPath = modelPath
    self.modelVersion = modelVersion
    self.momcBin = momcBin
    self.moduleName = moduleName
    self.outputDir = outputDir
    self.sourceDir = sourceDir
  }
}

/// Runtime request model for `generate`.
///
/// Unlike `GenerateTemplate`, this struct should already contain resolved defaults.
public struct GenerateRequest: Sendable, Equatable {
  public let modelPath: String
  public let modelVersion: String?
  public let momcBin: String?
  public let outputDir: String
  public let moduleName: String
  public let typeMappings: ToolingTypeMappings
  public let attributeRules: ToolingAttributeRules
  public let accessLevel: ToolingAccessLevel
  public let singleFile: Bool
  public let splitByEntity: Bool
  public let overwrite: ToolingOverwriteMode
  public let cleanStale: Bool
  public let dryRun: Bool
  public let format: ToolingFormatMode
  public let headerTemplate: String?
  public let generateInit: Bool
  public let relationshipSetterPolicy: ToolingRelationshipSetterPolicy
  public let relationshipCountPolicy: ToolingRelationshipCountPolicy
  public let defaultDecodeFailurePolicy: ToolingDecodeFailurePolicy

  public init(
    modelPath: String,
    modelVersion: String?,
    momcBin: String?,
    outputDir: String,
    moduleName: String,
    typeMappings: ToolingTypeMappings,
    attributeRules: ToolingAttributeRules,
    accessLevel: ToolingAccessLevel,
    singleFile: Bool,
    splitByEntity: Bool,
    overwrite: ToolingOverwriteMode,
    cleanStale: Bool,
    dryRun: Bool,
    format: ToolingFormatMode,
    headerTemplate: String?,
    generateInit: Bool,
    relationshipSetterPolicy: ToolingRelationshipSetterPolicy,
    relationshipCountPolicy: ToolingRelationshipCountPolicy,
    defaultDecodeFailurePolicy: ToolingDecodeFailurePolicy
  ) {
    self.modelPath = modelPath
    self.modelVersion = modelVersion
    self.momcBin = momcBin
    self.outputDir = outputDir
    self.moduleName = moduleName
    self.typeMappings = typeMappings
    self.attributeRules = attributeRules
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

/// Runtime request model for `validate`.
public struct ValidateRequest: Sendable, Equatable {
  public let modelPath: String
  public let modelVersion: String?
  public let momcBin: String?
  public let sourceDir: String
  public let moduleName: String
  public let typeMappings: ToolingTypeMappings
  public let attributeRules: ToolingAttributeRules
  public let include: [String]
  public let exclude: [String]
  public let level: ToolingValidationLevel
  public let report: ToolingReportFormat
  public let failOnWarning: Bool
  public let maxIssues: Int

  public init(
    modelPath: String,
    modelVersion: String?,
    momcBin: String?,
    sourceDir: String,
    moduleName: String,
    typeMappings: ToolingTypeMappings,
    attributeRules: ToolingAttributeRules,
    include: [String],
    exclude: [String],
    level: ToolingValidationLevel,
    report: ToolingReportFormat,
    failOnWarning: Bool,
    maxIssues: Int
  ) {
    self.modelPath = modelPath
    self.modelVersion = modelVersion
    self.momcBin = momcBin
    self.sourceDir = sourceDir
    self.moduleName = moduleName
    self.typeMappings = typeMappings
    self.attributeRules = attributeRules
    self.include = include
    self.exclude = exclude
    self.level = level
    self.report = report
    self.failOnWarning = failOnWarning
    self.maxIssues = maxIssues
  }
}

/// Runtime request model for `inspect`.
public struct InspectRequest: Sendable, Equatable {
  public let modelPath: String
  public let modelVersion: String?
  public let momcBin: String?

  public init(modelPath: String, modelVersion: String?, momcBin: String?) {
    self.modelPath = modelPath
    self.modelVersion = modelVersion
    self.momcBin = momcBin
  }
}

/// CLI-only override carrier merged on top of `GenerateTemplate`.
public struct GenerateRequestOverrides: Sendable, Equatable {
  public var modelPath: String?
  public var modelVersion: String?
  public var momcBin: String?
  public var outputDir: String?
  public var moduleName: String?
  public var accessLevel: ToolingAccessLevel?
  public var singleFile: Bool?
  public var splitByEntity: Bool?
  public var overwrite: ToolingOverwriteMode?
  public var cleanStale: Bool?
  public var dryRun: Bool?
  public var format: ToolingFormatMode?
  public var headerTemplate: String?
  public var generateInit: Bool?
  public var relationshipSetterPolicy: ToolingRelationshipSetterPolicy?
  public var relationshipCountPolicy: ToolingRelationshipCountPolicy?
  public var defaultDecodeFailurePolicy: ToolingDecodeFailurePolicy?

  public init() {}
}

/// CLI-only override carrier merged on top of `ValidateTemplate`.
public struct ValidateRequestOverrides: Sendable, Equatable {
  public var modelPath: String?
  public var modelVersion: String?
  public var momcBin: String?
  public var sourceDir: String?
  public var moduleName: String?
  public var include: [String]?
  public var exclude: [String]?
  public var level: ToolingValidationLevel?
  public var report: ToolingReportFormat?
  public var failOnWarning: Bool?
  public var maxIssues: Int?

  public init() {}
}
