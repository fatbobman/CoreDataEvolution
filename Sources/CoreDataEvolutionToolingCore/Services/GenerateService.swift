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
/// The service stops at disk writes. External formatter execution still belongs to CLI/adapters.
public enum GenerateService {
  public static func run(_ request: GenerateRequest) throws -> GenerateResult {
    let loadedModel = try ToolingModelLoader.loadValidatedSourceModel(
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
      moduleName: request.moduleName,
      header: request.headerTemplate
    )
    let extensionSources = ToolingSourceRenderer.renderExtensionStubs(
      from: buildResult.modelIR,
      header: request.headerTemplate,
      enabled: request.emitExtensionStubs
    )
    let allGeneratedSources = generatedSources + extensionSources
    let filePlan = try ToolingFilePlanner.makeFilePlan(
      from: allGeneratedSources,
      outputDir: request.outputDir
    )
    let writeResult = try ToolingFileWriter.apply(
      plan: filePlan,
      outputDir: request.outputDir,
      overwrite: request.overwrite,
      cleanStale: request.cleanStale,
      dryRun: request.dryRun
    )

    return .init(
      modelIR: buildResult.modelIR,
      generatedSources: allGeneratedSources,
      filePlan: filePlan,
      writeResult: writeResult,
      diagnostics: buildResult.diagnostics
    )
  }

  private static func validateGenerateRequest(
    _ request: GenerateRequest,
    against model: NSManagedObjectModel
  ) throws {
    try validateResolvedToolingSchemaConfig(
      .init(generateRequest: request),
      against: model,
      context: "generate"
    )
  }
}
