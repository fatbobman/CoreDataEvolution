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

/// Resolves a runtime `ValidateRequest` from config-file values and CLI overrides.
///
/// Validation needs the same naming and storage rules as generation, so the runtime request also
/// carries the generation-facing defaults that affect source comparison.
public func makeValidateRequest(
  config: ValidateTemplate,
  overrides: ValidateRequestOverrides = .init(),
  configDirectory: URL? = nil
) throws -> ValidateRequest {
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
    sourceDir: resolvePathValue(
      overrides.sourceDir ?? config.sourceDir,
      relativeTo: configDirectory
    ),
    moduleName: overrides.moduleName ?? config.moduleName,
    typeMappings: mergeToolingTypeMappings(config.typeMappings),
    attributeRules: config.attributeRules ?? .init(),
    accessLevel: overrides.accessLevel ?? config.accessLevel ?? .internal,
    singleFile: overrides.singleFile ?? config.singleFile ?? false,
    splitByEntity: overrides.splitByEntity ?? config.splitByEntity ?? true,
    headerTemplate: headerTemplate,
    generateInit: overrides.generateInit ?? config.generateInit ?? false,
    relationshipSetterPolicy: overrides.relationshipSetterPolicy
      ?? config.relationshipSetterPolicy ?? .warning,
    relationshipCountPolicy: overrides.relationshipCountPolicy
      ?? config.relationshipCountPolicy ?? .none,
    defaultDecodeFailurePolicy: overrides.defaultDecodeFailurePolicy
      ?? config.defaultDecodeFailurePolicy ?? .fallbackToDefaultValue,
    include: overrides.include ?? config.include ?? [],
    exclude: overrides.exclude ?? config.exclude ?? [],
    level: overrides.level ?? config.level ?? .conformance,
    report: overrides.report ?? config.report ?? .text,
    failOnWarning: overrides.failOnWarning ?? config.failOnWarning ?? false,
    maxIssues: overrides.maxIssues ?? config.maxIssues ?? 200
  )
}
