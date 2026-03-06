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

/// Builds in-memory Swift sources from a Core Data model and resolved tooling rules.
///
/// Session 4 stops before file planning and disk writes. The service returns generated source
/// units that session 5 will later wrap into overwrite and formatting workflows.
public enum GenerateService {
  public static func run(_ request: GenerateRequest) throws -> GenerateResult {
    let loadedModel = try ToolingModelLoader.loadModel(
      modelPath: request.modelPath,
      modelVersion: request.modelVersion,
      momcBin: request.momcBin
    )

    try validateGenerateRequest(
      request,
      against: loadedModel.model
    )

    let buildResult = ToolingIRBuilder.build(
      from: loadedModel,
      request: .init(generateRequest: request)
    )

    let generatedSources = try ToolingSourceRenderer.renderSources(
      from: buildResult.modelIR,
      header: request.headerTemplate
    )

    return .init(
      modelIR: buildResult.modelIR,
      generatedSources: generatedSources,
      diagnostics: buildResult.diagnostics
    )
  }

  private static func validateGenerateRequest(
    _ request: GenerateRequest,
    against model: NSManagedObjectModel
  ) throws {
    let template = GenerateTemplate(
      modelPath: request.modelPath,
      modelVersion: request.modelVersion,
      momcBin: request.momcBin,
      outputDir: request.outputDir,
      moduleName: request.moduleName,
      typeMappings: request.typeMappings,
      attributeRules: request.attributeRules,
      accessLevel: request.accessLevel,
      singleFile: request.singleFile,
      splitByEntity: request.splitByEntity,
      overwrite: request.overwrite,
      cleanStale: request.cleanStale,
      dryRun: request.dryRun,
      format: request.format,
      headerTemplate: request.headerTemplate,
      generateInit: request.generateInit,
      relationshipSetterPolicy: request.relationshipSetterPolicy,
      relationshipCountPolicy: request.relationshipCountPolicy,
      defaultDecodeFailurePolicy: request.defaultDecodeFailurePolicy
    )

    try validateToolingConfigTemplate(
      .init(
        schemaVersion: toolingSupportedSchemaVersion,
        generate: template,
        validate: nil
      ),
      against: model
    )
  }
}
