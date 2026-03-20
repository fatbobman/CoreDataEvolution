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
  public let style: ToolingBootstrapConfigStyle

  public init(
    modelPath: String,
    modelVersion: String?,
    momcBin: String?,
    moduleName: String,
    outputDir: String,
    sourceDir: String,
    style: ToolingBootstrapConfigStyle = .compact
  ) {
    self.modelPath = modelPath
    self.modelVersion = modelVersion
    self.momcBin = momcBin
    self.moduleName = moduleName
    self.outputDir = outputDir
    self.sourceDir = sourceDir
    self.style = style
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
  public let relationshipRules: ToolingRelationshipRules
  public let compositionRules: ToolingCompositionRules
  public let accessLevel: ToolingAccessLevel
  public let singleFile: Bool
  public let splitByEntity: Bool
  public let overwrite: ToolingOverwriteMode
  public let cleanStale: Bool
  public let dryRun: Bool
  public let format: ToolingFormatMode
  public let headerTemplate: String?
  public let emitExtensionStubs: Bool
  public let generateInit: Bool
  public let generateToManyCount: Bool
  public let defaultDecodeFailurePolicy: ToolingDecodeFailurePolicy

  public init(
    modelPath: String,
    modelVersion: String?,
    momcBin: String?,
    outputDir: String,
    moduleName: String,
    typeMappings: ToolingTypeMappings,
    attributeRules: ToolingAttributeRules,
    relationshipRules: ToolingRelationshipRules = .init(),
    compositionRules: ToolingCompositionRules = .init(),
    accessLevel: ToolingAccessLevel,
    singleFile: Bool,
    splitByEntity: Bool,
    overwrite: ToolingOverwriteMode,
    cleanStale: Bool,
    dryRun: Bool,
    format: ToolingFormatMode,
    headerTemplate: String?,
    emitExtensionStubs: Bool = false,
    generateInit: Bool,
    generateToManyCount: Bool = true,
    defaultDecodeFailurePolicy: ToolingDecodeFailurePolicy
  ) {
    self.modelPath = modelPath
    self.modelVersion = modelVersion
    self.momcBin = momcBin
    self.outputDir = outputDir
    self.moduleName = moduleName
    self.typeMappings = typeMappings
    self.attributeRules = attributeRules
    self.relationshipRules = relationshipRules
    self.compositionRules = compositionRules
    self.accessLevel = accessLevel
    self.singleFile = singleFile
    self.splitByEntity = splitByEntity
    self.overwrite = overwrite
    self.cleanStale = cleanStale
    self.dryRun = dryRun
    self.format = format
    self.headerTemplate = headerTemplate
    self.emitExtensionStubs = emitExtensionStubs
    self.generateInit = generateInit
    self.generateToManyCount = generateToManyCount
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
  public let relationshipRules: ToolingRelationshipRules
  public let compositionRules: ToolingCompositionRules
  public let accessLevel: ToolingAccessLevel
  public let singleFile: Bool
  public let splitByEntity: Bool
  public let headerTemplate: String?
  public let generateInit: Bool
  public let generateToManyCount: Bool
  public let defaultDecodeFailurePolicy: ToolingDecodeFailurePolicy
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
    relationshipRules: ToolingRelationshipRules = .init(),
    compositionRules: ToolingCompositionRules = .init(),
    accessLevel: ToolingAccessLevel,
    singleFile: Bool,
    splitByEntity: Bool,
    headerTemplate: String?,
    generateInit: Bool,
    generateToManyCount: Bool = true,
    defaultDecodeFailurePolicy: ToolingDecodeFailurePolicy,
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
    self.relationshipRules = relationshipRules
    self.compositionRules = compositionRules
    self.accessLevel = accessLevel
    self.singleFile = singleFile
    self.splitByEntity = splitByEntity
    self.headerTemplate = headerTemplate
    self.generateInit = generateInit
    self.generateToManyCount = generateToManyCount
    self.defaultDecodeFailurePolicy = defaultDecodeFailurePolicy
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
  public let typeMappings: ToolingTypeMappings
  public let attributeRules: ToolingAttributeRules
  public let relationshipRules: ToolingRelationshipRules
  public let compositionRules: ToolingCompositionRules
  public let accessLevel: ToolingAccessLevel
  public let singleFile: Bool
  public let splitByEntity: Bool
  public let generateInit: Bool
  public let generateToManyCount: Bool
  public let defaultDecodeFailurePolicy: ToolingDecodeFailurePolicy

  public init(
    modelPath: String,
    modelVersion: String?,
    momcBin: String?,
    typeMappings: ToolingTypeMappings = makeDefaultToolingTypeMappings(),
    attributeRules: ToolingAttributeRules = .init(),
    relationshipRules: ToolingRelationshipRules = .init(),
    compositionRules: ToolingCompositionRules = .init(),
    accessLevel: ToolingAccessLevel = .internal,
    singleFile: Bool = false,
    splitByEntity: Bool = true,
    generateInit: Bool = false,
    generateToManyCount: Bool = true,
    defaultDecodeFailurePolicy: ToolingDecodeFailurePolicy = .fallbackToDefaultValue
  ) {
    self.modelPath = modelPath
    self.modelVersion = modelVersion
    self.momcBin = momcBin
    self.typeMappings = typeMappings
    self.attributeRules = attributeRules
    self.relationshipRules = relationshipRules
    self.compositionRules = compositionRules
    self.accessLevel = accessLevel
    self.singleFile = singleFile
    self.splitByEntity = splitByEntity
    self.generateInit = generateInit
    self.generateToManyCount = generateToManyCount
    self.defaultDecodeFailurePolicy = defaultDecodeFailurePolicy
  }
}

extension InspectRequest {
  /// Reuses the inspect pipeline as the model-to-IR front-end for generate.
  public init(generateRequest: GenerateRequest) {
    self.init(
      modelPath: generateRequest.modelPath,
      modelVersion: generateRequest.modelVersion,
      momcBin: generateRequest.momcBin,
      typeMappings: generateRequest.typeMappings,
      attributeRules: generateRequest.attributeRules,
      relationshipRules: generateRequest.relationshipRules,
      compositionRules: generateRequest.compositionRules,
      accessLevel: generateRequest.accessLevel,
      singleFile: generateRequest.singleFile,
      splitByEntity: generateRequest.splitByEntity,
      generateInit: generateRequest.generateInit,
      generateToManyCount: generateRequest.generateToManyCount,
      defaultDecodeFailurePolicy: generateRequest.defaultDecodeFailurePolicy
    )
  }

  /// Reuses the inspect pipeline as the model-to-IR front-end for validate.
  public init(validateRequest: ValidateRequest) {
    self.init(
      modelPath: validateRequest.modelPath,
      modelVersion: validateRequest.modelVersion,
      momcBin: validateRequest.momcBin,
      typeMappings: validateRequest.typeMappings,
      attributeRules: validateRequest.attributeRules,
      relationshipRules: validateRequest.relationshipRules,
      compositionRules: validateRequest.compositionRules,
      accessLevel: validateRequest.accessLevel,
      singleFile: validateRequest.singleFile,
      splitByEntity: validateRequest.splitByEntity,
      generateInit: validateRequest.generateInit,
      generateToManyCount: validateRequest.generateToManyCount,
      defaultDecodeFailurePolicy: validateRequest.defaultDecodeFailurePolicy
    )
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
  public var emitExtensionStubs: Bool?
  public var generateInit: Bool?
  public var generateToManyCount: Bool?
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
  public var accessLevel: ToolingAccessLevel?
  public var singleFile: Bool?
  public var splitByEntity: Bool?
  public var headerTemplate: String?
  public var generateInit: Bool?
  public var generateToManyCount: Bool?
  public var defaultDecodeFailurePolicy: ToolingDecodeFailurePolicy?
  public var include: [String]?
  public var exclude: [String]?
  public var level: ToolingValidationLevel?
  public var report: ToolingReportFormat?
  public var failOnWarning: Bool?
  public var maxIssues: Int?

  public init() {}
}
