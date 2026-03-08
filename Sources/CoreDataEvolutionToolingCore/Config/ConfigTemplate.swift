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

/// Controls whether `init-config` emits a compact or fully-populated template.
public enum ToolingConfigTemplatePreset: String, Codable, Sendable {
  case minimal
  case full
}

/// Root JSON config object shared by `init-config`, `bootstrap-config`, and future loaders.
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

/// Config template for `generate`.
///
/// Keep this focused on stable, serializable settings. Runtime-only objects should live in
/// request/result models or future engine types.
public struct GenerateTemplate: Codable, Sendable, Equatable {
  public let modelPath: String
  public let modelVersion: String?
  public let momcBin: String?
  public let outputDir: String
  public let moduleName: String
  public let typeMappings: ToolingTypeMappings?
  public let attributeRules: ToolingAttributeRules?
  public let relationshipRules: ToolingRelationshipRules?
  public let compositionRules: ToolingCompositionRules?
  public let accessLevel: ToolingAccessLevel?
  public let singleFile: Bool?
  public let splitByEntity: Bool?
  public let overwrite: ToolingOverwriteMode?
  public let cleanStale: Bool?
  public let dryRun: Bool?
  public let format: ToolingFormatMode?
  public let headerTemplate: String?
  public let emitExtensionStubs: Bool?
  public let generateInit: Bool?
  public let defaultDecodeFailurePolicy: ToolingDecodeFailurePolicy?

  public init(
    modelPath: String,
    modelVersion: String?,
    momcBin: String?,
    outputDir: String,
    moduleName: String,
    typeMappings: ToolingTypeMappings?,
    attributeRules: ToolingAttributeRules?,
    relationshipRules: ToolingRelationshipRules? = nil,
    compositionRules: ToolingCompositionRules? = nil,
    accessLevel: ToolingAccessLevel?,
    singleFile: Bool?,
    splitByEntity: Bool?,
    overwrite: ToolingOverwriteMode?,
    cleanStale: Bool?,
    dryRun: Bool?,
    format: ToolingFormatMode?,
    headerTemplate: String?,
    emitExtensionStubs: Bool? = nil,
    generateInit: Bool?,
    defaultDecodeFailurePolicy: ToolingDecodeFailurePolicy?
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
    self.defaultDecodeFailurePolicy = defaultDecodeFailurePolicy
  }
}

/// Config template for `validate`.
public struct ValidateTemplate: Codable, Sendable, Equatable {
  public let modelPath: String
  public let modelVersion: String?
  public let momcBin: String?
  public let sourceDir: String
  public let moduleName: String
  public let typeMappings: ToolingTypeMappings?
  public let attributeRules: ToolingAttributeRules?
  public let relationshipRules: ToolingRelationshipRules?
  public let compositionRules: ToolingCompositionRules?
  public let accessLevel: ToolingAccessLevel?
  public let singleFile: Bool?
  public let splitByEntity: Bool?
  public let headerTemplate: String?
  public let generateInit: Bool?
  public let defaultDecodeFailurePolicy: ToolingDecodeFailurePolicy?
  public let include: [String]?
  public let exclude: [String]?
  public let level: ToolingValidationLevel?
  public let report: ToolingReportFormat?
  public let failOnWarning: Bool?
  public let maxIssues: Int?

  public init(
    modelPath: String,
    modelVersion: String?,
    momcBin: String?,
    sourceDir: String,
    moduleName: String,
    typeMappings: ToolingTypeMappings?,
    attributeRules: ToolingAttributeRules?,
    relationshipRules: ToolingRelationshipRules? = nil,
    compositionRules: ToolingCompositionRules? = nil,
    accessLevel: ToolingAccessLevel?,
    singleFile: Bool?,
    splitByEntity: Bool?,
    headerTemplate: String?,
    generateInit: Bool?,
    defaultDecodeFailurePolicy: ToolingDecodeFailurePolicy?,
    include: [String]?,
    exclude: [String]?,
    level: ToolingValidationLevel?,
    report: ToolingReportFormat?,
    failOnWarning: Bool?,
    maxIssues: Int?
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
    self.defaultDecodeFailurePolicy = defaultDecodeFailurePolicy
    self.include = include
    self.exclude = exclude
    self.level = level
    self.report = report
    self.failOnWarning = failOnWarning
    self.maxIssues = maxIssues
  }
}

/// Creates the built-in config templates used by `init-config`.
///
/// `minimal` keeps only the required shape.
/// `full` emits all supported options and default values so users can edit in place.
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
        typeMappings: nil,
        attributeRules: nil,
        relationshipRules: nil,
        compositionRules: nil,
        accessLevel: nil,
        singleFile: nil,
        splitByEntity: nil,
        overwrite: nil,
        cleanStale: nil,
        dryRun: nil,
        format: nil,
        headerTemplate: nil,
        emitExtensionStubs: nil,
        generateInit: nil,
        defaultDecodeFailurePolicy: nil
      ),
      validate: .init(
        modelPath: "Models/AppModel.xcdatamodeld",
        modelVersion: nil,
        momcBin: nil,
        sourceDir: "Sources/AppModels",
        moduleName: "AppModels",
        typeMappings: nil,
        attributeRules: nil,
        relationshipRules: nil,
        compositionRules: nil,
        accessLevel: nil,
        singleFile: nil,
        splitByEntity: nil,
        headerTemplate: nil,
        generateInit: nil,
        defaultDecodeFailurePolicy: nil,
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
        typeMappings: makeDefaultToolingTypeMappings(),
        attributeRules: .init(),
        relationshipRules: .init(),
        compositionRules: .init(),
        accessLevel: .internal,
        singleFile: false,
        splitByEntity: true,
        overwrite: ToolingOverwriteMode.none,
        cleanStale: false,
        dryRun: false,
        format: ToolingFormatMode.none,
        headerTemplate: nil,
        emitExtensionStubs: false,
        generateInit: false,
        defaultDecodeFailurePolicy: .fallbackToDefaultValue
      ),
      validate: .init(
        modelPath: "Models/AppModel.xcdatamodeld",
        modelVersion: nil,
        momcBin: nil,
        sourceDir: "Sources/AppModels",
        moduleName: "AppModels",
        typeMappings: makeDefaultToolingTypeMappings(),
        attributeRules: .init(),
        relationshipRules: .init(),
        compositionRules: .init(),
        accessLevel: .internal,
        singleFile: false,
        splitByEntity: true,
        headerTemplate: nil,
        generateInit: false,
        defaultDecodeFailurePolicy: .fallbackToDefaultValue,
        include: [],
        exclude: [],
        level: .conformance,
        report: .text,
        failOnWarning: false,
        maxIssues: 200
      )
    )
  }
}

/// Uses stable formatting so generated config files remain diff-friendly.
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
    let template = try decoder.decode(ToolingConfigTemplate.self, from: data)
    try validateToolingConfigTemplate(template)
    return template
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
  /// Merges config-file values with CLI overrides.
  ///
  /// Priority is: CLI override > config file > built-in default.
  public init(
    config: GenerateTemplate,
    overrides: GenerateRequestOverrides = .init(),
    configDirectory: URL? = nil
  ) throws {
    self = try makeGenerateRequest(
      config: config,
      overrides: overrides,
      configDirectory: configDirectory
    )
  }
}

extension ValidateRequest {
  /// Merges config-file values with CLI overrides.
  public init(
    config: ValidateTemplate,
    overrides: ValidateRequestOverrides = .init(),
    configDirectory: URL? = nil
  ) throws {
    self = try makeValidateRequest(
      config: config,
      overrides: overrides,
      configDirectory: configDirectory
    )
  }
}

extension InspectRequest {
  /// Resolves inspect options from the generate section because inspect mirrors generation-facing
  /// naming and storage rules.
  public init(
    config: GenerateTemplate,
    modelPathOverride: String? = nil,
    modelVersionOverride: String? = nil,
    momcBinOverride: String? = nil,
    configDirectory: URL? = nil
  ) {
    self.init(
      modelPath: resolvePathValue(
        modelPathOverride ?? config.modelPath,
        relativeTo: configDirectory
      ),
      modelVersion: modelVersionOverride ?? config.modelVersion,
      momcBin: resolveOptionalPathValue(
        momcBinOverride ?? config.momcBin,
        relativeTo: configDirectory
      ),
      typeMappings: mergeToolingTypeMappings(config.typeMappings),
      attributeRules: config.attributeRules ?? .init(),
      relationshipRules: config.relationshipRules ?? .init(),
      compositionRules: config.compositionRules ?? .init(),
      accessLevel: config.accessLevel ?? .internal,
      singleFile: config.singleFile ?? false,
      splitByEntity: config.splitByEntity ?? true,
      generateInit: config.generateInit ?? false,
      defaultDecodeFailurePolicy: config.defaultDecodeFailurePolicy ?? .fallbackToDefaultValue
    )
  }
}
