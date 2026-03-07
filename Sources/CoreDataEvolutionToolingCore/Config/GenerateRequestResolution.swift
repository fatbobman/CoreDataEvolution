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

/// Resolves a runtime `GenerateRequest` from config-file values and CLI overrides.
///
/// The runtime request carries parsed header-template contents instead of a path so later engine
/// layers can stay filesystem-agnostic.
public func makeGenerateRequest(
  config: GenerateTemplate,
  overrides: GenerateRequestOverrides = .init(),
  configDirectory: URL? = nil
) throws -> GenerateRequest {
  let headerTemplatePath = overrides.headerTemplate ?? config.headerTemplate
  let headerTemplate = try loadGenerateHeaderTemplate(
    at: headerTemplatePath,
    relativeTo: configDirectory
  )

  return .init(
    modelPath: resolvePathValue(
      overrides.modelPath ?? config.modelPath,
      relativeTo: configDirectory
    ),
    modelVersion: overrides.modelVersion ?? config.modelVersion,
    momcBin: resolveOptionalPathValue(
      overrides.momcBin ?? config.momcBin,
      relativeTo: configDirectory
    ),
    outputDir: resolvePathValue(
      overrides.outputDir ?? config.outputDir,
      relativeTo: configDirectory
    ),
    moduleName: overrides.moduleName ?? config.moduleName,
    typeMappings: mergeToolingTypeMappings(config.typeMappings),
    attributeRules: config.attributeRules ?? .init(),
    relationshipRules: config.relationshipRules ?? .init(),
    accessLevel: overrides.accessLevel ?? config.accessLevel ?? .internal,
    singleFile: overrides.singleFile ?? config.singleFile ?? false,
    splitByEntity: overrides.splitByEntity ?? config.splitByEntity ?? true,
    overwrite: overrides.overwrite ?? config.overwrite ?? .none,
    cleanStale: overrides.cleanStale ?? config.cleanStale ?? false,
    dryRun: overrides.dryRun ?? config.dryRun ?? false,
    format: overrides.format ?? config.format ?? .none,
    headerTemplate: headerTemplate,
    emitExtensionStubs: overrides.emitExtensionStubs ?? config.emitExtensionStubs ?? false,
    generateInit: overrides.generateInit ?? config.generateInit ?? false,
    relationshipSetterPolicy: overrides.relationshipSetterPolicy
      ?? config.relationshipSetterPolicy ?? .warning,
    relationshipCountPolicy: overrides.relationshipCountPolicy
      ?? config.relationshipCountPolicy ?? .none,
    defaultDecodeFailurePolicy: overrides.defaultDecodeFailurePolicy
      ?? config.defaultDecodeFailurePolicy ?? .fallbackToDefaultValue
  )
}

/// Loads an optional header template file.
///
/// Config-provided paths resolve relative to the config file directory. CLI overrides should be
/// normalized by the adapter layer before reaching this helper if they need a different base.
public func loadGenerateHeaderTemplate(
  at path: String?,
  relativeTo baseDirectory: URL? = nil
) throws -> String? {
  guard let path else { return nil }

  let headerURL = resolveHeaderTemplateURL(path: path, relativeTo: baseDirectory)
  do {
    return try String(contentsOf: headerURL, encoding: .utf8)
  } catch {
    throw ToolingFailure.runtime(
      .ioFailed,
      "failed to read header template at '\(headerURL.path)' (\(error.localizedDescription))."
    )
  }
}

private func resolveHeaderTemplateURL(path: String, relativeTo baseDirectory: URL?) -> URL {
  resolveURLPath(path, relativeTo: baseDirectory)
}

func resolvePathValue(_ path: String, relativeTo baseDirectory: URL?) -> String {
  resolveURLPath(path, relativeTo: baseDirectory).path
}

func resolveOptionalPathValue(_ path: String?, relativeTo baseDirectory: URL?) -> String? {
  guard let path else { return nil }
  return resolvePathValue(path, relativeTo: baseDirectory)
}

func resolveURLPath(_ path: String, relativeTo baseDirectory: URL?) -> URL {
  if (path as NSString).isAbsolutePath {
    return URL(fileURLWithPath: path)
  }
  if let baseDirectory { return baseDirectory.appendingPathComponent(path) }
  return URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(path)
}
