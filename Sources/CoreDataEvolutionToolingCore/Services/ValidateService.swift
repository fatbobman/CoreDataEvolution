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

/// Validates developer-authored source against the model and resolved tooling rules.
///
/// `conformance` parses source into a dedicated IR and checks it against the same model/config
/// inputs used by generate. `exact` builds on top of `conformance` and additionally performs exact
/// drift checks against tool-managed files on disk.
public enum ValidateService {
  public static func run(_ request: ValidateRequest) throws -> ValidateResult {
    let loadedModel = try ToolingModelLoader.loadValidatedSourceModel(
      modelPath: request.modelPath,
      modelVersion: request.modelVersion,
      momcBin: request.momcBin
    )

    try validateValidateRequest(
      request,
      against: loadedModel.model
    )

    let buildResult = ToolingIRBuilder.build(
      from: loadedModel,
      request: .init(validateRequest: request)
    )
    let sourceIR = try ToolingSourceParser.parse(
      sourceDirectory: request.sourceDir,
      include: request.include,
      exclude: request.exclude
    )

    var allDiagnostics =
      buildResult.diagnostics
      + ToolingValidateComparator.compareQuick(
        expected: buildResult.modelIR,
        actual: sourceIR,
        level: request.level
      )

    if request.level == .exact {
      let expectedFilePlan = try makeStrictExpectedFilePlan(
        modelIR: buildResult.modelIR,
        request: request
      )
      allDiagnostics += try ToolingManagedFileComparator.compareStrict(
        expected: expectedFilePlan,
        sourceDirectory: request.sourceDir,
        include: request.include,
        exclude: request.exclude
      )
    }

    let diagnostics = limitDiagnostics(
      allDiagnostics,
      maxIssues: request.maxIssues
    )

    return .init(
      modelIR: buildResult.modelIR,
      sourceIR: sourceIR,
      diagnostics: diagnostics,
      errorCount: allDiagnostics.filter { $0.severity == .error }.count,
      warningCount: allDiagnostics.filter { $0.severity == .warning }.count
    )
  }

  private static func validateValidateRequest(
    _ request: ValidateRequest,
    against model: NSManagedObjectModel
  ) throws {
    let template = ValidateTemplate(
      modelPath: request.modelPath,
      modelVersion: request.modelVersion,
      momcBin: request.momcBin,
      sourceDir: request.sourceDir,
      moduleName: request.moduleName,
      typeMappings: request.typeMappings,
      attributeRules: request.attributeRules,
      relationshipRules: request.relationshipRules,
      compositionRules: request.compositionRules,
      accessLevel: request.accessLevel,
      singleFile: request.singleFile,
      splitByEntity: request.splitByEntity,
      headerTemplate: request.headerTemplate,
      generateInit: request.generateInit,
      defaultDecodeFailurePolicy: request.defaultDecodeFailurePolicy,
      include: request.include,
      exclude: request.exclude,
      level: request.level,
      report: request.report,
      failOnWarning: request.failOnWarning,
      maxIssues: request.maxIssues
    )

    try validateToolingConfigTemplate(
      .init(
        schemaVersion: toolingSupportedSchemaVersion,
        generate: nil,
        validate: template
      ),
      against: model
    )
  }

  private static func makeStrictExpectedFilePlan(
    modelIR: ToolingModelIR,
    request: ValidateRequest
  ) throws -> [ToolingGeneratedFilePlan] {
    let generatedSources = try ToolingSourceRenderer.renderSources(
      from: modelIR,
      moduleName: request.moduleName,
      header: request.headerTemplate
    )
    return try ToolingFilePlanner.makeFilePlan(
      from: generatedSources,
      outputDir: request.sourceDir
    )
  }

  private static func limitDiagnostics(
    _ diagnostics: [ToolingDiagnostic],
    maxIssues: Int
  ) -> [ToolingDiagnostic] {
    guard diagnostics.count > maxIssues else { return diagnostics }

    var limited = Array(diagnostics.prefix(maxIssues))
    limited.append(
      .init(
        severity: .note,
        code: nil,
        message:
          "validate truncated \(diagnostics.count - maxIssues) additional issues after reaching maxIssues=\(maxIssues)."
      )
    )
    return limited
  }
}
