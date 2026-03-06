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

public enum BootstrapConfigService {
  public static func run(_ request: BootstrapConfigRequest) throws -> BootstrapConfigResult {
    let loadedModel = try ToolingModelLoader.loadModel(
      modelPath: request.modelPath,
      modelVersion: request.modelVersion,
      momcBin: request.momcBin
    )

    let typeMappings = makeDefaultToolingTypeMappings()
    let attributeRules = makeAttributeRules(
      from: loadedModel.model
    )

    let template = ToolingConfigTemplate(
      schemaVersion: toolingSupportedSchemaVersion,
      generate: .init(
        modelPath: request.modelPath,
        modelVersion: request.modelVersion,
        momcBin: request.momcBin,
        outputDir: request.outputDir,
        moduleName: request.moduleName,
        typeMappings: typeMappings,
        attributeRules: attributeRules,
        accessLevel: .internal,
        singleFile: false,
        splitByEntity: true,
        overwrite: ToolingOverwriteMode.none,
        cleanStale: false,
        dryRun: false,
        format: ToolingFormatMode.none,
        headerTemplate: nil,
        generateInit: false,
        relationshipSetterPolicy: .warning,
        relationshipCountPolicy: ToolingRelationshipGenerationPolicy.none,
        defaultDecodeFailurePolicy: .fallbackToDefaultValue
      ),
      validate: .init(
        modelPath: request.modelPath,
        modelVersion: request.modelVersion,
        sourceDir: request.sourceDir,
        moduleName: request.moduleName,
        typeMappings: typeMappings,
        attributeRules: attributeRules,
        include: [],
        exclude: [],
        level: .quick,
        report: .text,
        failOnWarning: false,
        maxIssues: 200
      )
    )

    let diagnostics = makeDiagnostics(from: loadedModel.model)

    do {
      let jsonData = try encodeToolingJSON(template)
      return .init(
        template: template,
        jsonData: jsonData,
        diagnostics: diagnostics
      )
    } catch {
      throw ToolingFailure.runtime(
        .jsonEncodeFailed,
        "failed to encode bootstrap config as JSON."
      )
    }
  }

  private static func makeAttributeRules(
    from model: NSManagedObjectModel
  ) -> ToolingAttributeRules {
    var entities: [String: [String: ToolingAttributeRule]] = [:]

    for entity in model.entities.sorted(by: { ($0.name ?? "") < ($1.name ?? "") }) {
      guard let entityName = entity.name else { continue }

      let attributeRules = entity.attributesByName
        .sorted(by: { $0.key < $1.key })
        .reduce(into: [String: ToolingAttributeRule]()) { partialResult, item in
          let (persistentName, attribute) = item
          partialResult[persistentName] = makeRule(for: attribute)
        }

      entities[entityName] = attributeRules
    }

    return .init(entities: entities)
  }

  private static func makeRule(for attribute: NSAttributeDescription) -> ToolingAttributeRule {
    switch attribute.attributeType {
    case .transformableAttributeType:
      return .init(
        storageMethod: .transformed,
        transformerType: attribute.valueTransformerName
      )
    default:
      return .init()
    }
  }

  private static func makeDiagnostics(from model: NSManagedObjectModel) -> [ToolingDiagnostic] {
    var diagnostics: [ToolingDiagnostic] = []

    for entity in model.entities.sorted(by: { ($0.name ?? "") < ($1.name ?? "") }) {
      guard let entityName = entity.name else { continue }
      for attribute in entity.attributesByName.values.sorted(by: { $0.name < $1.name }) {
        if attribute.attributeType == .transformableAttributeType {
          diagnostics.append(
            .init(
              severity: .note,
              code: nil,
              message:
                "bootstrap-config emitted a transformable placeholder for '\(entityName).\(attribute.name)'. Fill in swiftType and confirm transformerType before generate/validate.",
              hint: attribute.valueTransformerName == nil
                ? "Set attributeRules.\(entityName).\(attribute.name).transformerType if this field should use a specific ValueTransformer."
                : nil
            )
          )
        }
      }
    }

    return diagnostics
  }
}
