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

/// Builds an editable config scaffold directly from a Core Data model.
///
/// The service supports two scaffold styles:
/// - `compact`: keep placeholders concise and omit same-name mappings
/// - `explicit`: emit a fully populated manifest with resolved default mappings
///
/// Both styles emit the full default `typeMappings` and add diagnostics for fields that still
/// require human decisions.
public enum BootstrapConfigService {
  public static func run(_ request: BootstrapConfigRequest) throws -> BootstrapConfigResult {
    let loadedModel = try ToolingModelLoader.loadValidatedSourceModel(
      modelPath: request.modelPath,
      modelVersion: request.modelVersion,
      momcBin: request.momcBin
    )

    try validateSupportedToolingModelSurface(loadedModel.model)

    let typeMappings = makeDefaultToolingTypeMappings()
    let attributeRules = makeAttributeRules(
      from: loadedModel.model,
      style: request.style
    )
    let relationshipRules = makeRelationshipRules(
      from: loadedModel.model,
      style: request.style
    )
    let compositionRules = makeCompositionRules(
      from: loadedModel.resolvedInput.selectedSourceURL,
      style: request.style
    )

    let template = ToolingConfigTemplate(
      schemaVersion: toolingSupportedSchemaVersion,
      generate: .init(
        modelPath: request.modelPath,
        modelVersion: loadedModel.resolvedInput.selectedVersionName ?? request.modelVersion,
        momcBin: request.momcBin,
        outputDir: request.outputDir,
        moduleName: request.moduleName,
        typeMappings: typeMappings,
        attributeRules: attributeRules,
        relationshipRules: relationshipRules,
        compositionRules: compositionRules,
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
        generateToManyCount: true,
        defaultDecodeFailurePolicy: .fallbackToDefaultValue
      ),
      validate: .init(
        modelPath: request.modelPath,
        modelVersion: loadedModel.resolvedInput.selectedVersionName ?? request.modelVersion,
        momcBin: request.momcBin,
        sourceDir: request.sourceDir,
        moduleName: request.moduleName,
        typeMappings: typeMappings,
        attributeRules: attributeRules,
        relationshipRules: relationshipRules,
        compositionRules: compositionRules,
        accessLevel: .internal,
        singleFile: false,
        splitByEntity: true,
        headerTemplate: nil,
        generateInit: false,
        generateToManyCount: true,
        defaultDecodeFailurePolicy: .fallbackToDefaultValue,
        include: [],
        exclude: [],
        level: .conformance,
        report: .text,
        failOnWarning: false,
        maxIssues: 200
      )
    )

    let diagnostics = makeDiagnostics(from: loadedModel.model)

    do {
      try validateToolingConfigTemplate(template)
      let jsonData = try encodeToolingJSON(template)
      return .init(
        template: template,
        jsonData: jsonData,
        diagnostics: diagnostics
      )
    } catch let failure as ToolingFailure {
      throw failure
    } catch {
      throw ToolingFailure.runtime(
        .jsonEncodeFailed,
        "failed to encode bootstrap config as JSON."
      )
    }
  }

  private static func makeAttributeRules(
    from model: NSManagedObjectModel,
    style: ToolingBootstrapConfigStyle
  ) -> ToolingAttributeRules {
    var entities: [String: [String: ToolingAttributeRule]] = [:]

    for entity in model.entities.sorted(by: { ($0.name ?? "") < ($1.name ?? "") }) {
      guard let entityName = entity.name else { continue }

      let attributeRules = entity.attributesByName
        .sorted(by: { $0.key < $1.key })
        .reduce(into: [String: ToolingAttributeRule]()) { partialResult, item in
          let (persistentName, attribute) = item
          partialResult[persistentName] = makeAttributeRule(
            for: attribute,
            persistentName: persistentName,
            style: style
          )
        }

      entities[entityName] = attributeRules
    }

    return .init(entities: entities)
  }

  private static func makeRelationshipRules(
    from model: NSManagedObjectModel,
    style: ToolingBootstrapConfigStyle
  ) -> ToolingRelationshipRules {
    var entities: [String: [String: ToolingRelationshipRule]] = [:]

    for entity in model.entities.sorted(by: { ($0.name ?? "") < ($1.name ?? "") }) {
      guard let entityName = entity.name else { continue }

      let relationshipRules = entity.relationshipsByName
        .sorted(by: { $0.key < $1.key })
        .reduce(into: [String: ToolingRelationshipRule]()) { partialResult, item in
          let (persistentName, _) = item
          partialResult[persistentName] = makeRelationshipRule(
            persistentName: persistentName,
            style: style
          )
        }

      entities[entityName] = relationshipRules
    }

    return .init(entities: entities)
  }

  // Rules in the bootstrap scaffold describe the editable mapping surface. `compact` keeps
  // same-name mappings implicit; `explicit` writes the resolved defaults to make the JSON a
  // complete manifest a developer can modify in place.
  private static func makeAttributeRule(
    for attribute: NSAttributeDescription,
    persistentName: String,
    style: ToolingBootstrapConfigStyle
  ) -> ToolingAttributeRule {
    switch attribute.attributeType {
    case .compositeAttributeType:
      return .init(
        swiftName: style == .explicit ? persistentName : nil,
        storageMethod: .composition
      )
    case .transformableAttributeType:
      return .init(
        swiftName: style == .explicit ? persistentName : nil,
        storageMethod: .transformed,
        transformerName: attribute.valueTransformerName
      )
    default:
      return .init(
        swiftName: style == .explicit ? persistentName : nil,
        storageMethod: style == .explicit ? .default : nil
      )
    }
  }

  private static func makeRelationshipRule(
    persistentName: String,
    style: ToolingBootstrapConfigStyle
  ) -> ToolingRelationshipRule {
    .init(swiftName: style == .explicit ? persistentName : nil)
  }

  private static func makeCompositionRules(
    from selectedSourceURL: URL,
    style: ToolingBootstrapConfigStyle
  ) -> ToolingCompositionRules {
    guard style == .explicit else { return .init() }
    let parser = ToolingCompositeSourceParser()
    guard let composites = parser.parseCompositeDefinitions(from: selectedSourceURL) else {
      return .init()
    }

    let types = composites.reduce(into: [String: [String: ToolingCompositionFieldRule]]()) {
      partialResult,
      item in
      partialResult[item.key] = item.value.reduce(into: [String: ToolingCompositionFieldRule]()) {
        fields,
        persistentName in
        fields[persistentName] = .init(swiftName: persistentName)
      }
    }

    return .init(types: types)
  }

  // Diagnostics are used to call out fields that need manual follow-up before `generate`.
  private static func makeDiagnostics(from model: NSManagedObjectModel) -> [ToolingDiagnostic] {
    var diagnostics: [ToolingDiagnostic] = []

    for entity in model.entities.sorted(by: { ($0.name ?? "") < ($1.name ?? "") }) {
      guard let entityName = entity.name else { continue }
      for attribute in entity.attributesByName.values.sorted(by: { $0.name < $1.name }) {
        if attribute.attributeType == .binaryDataAttributeType {
          diagnostics.append(
            .init(
              severity: .note,
              code: nil,
              message:
                "bootstrap-config kept '\(entityName).\(attribute.name)' on the default Binary -> Data mapping.",
              hint:
                "If this field should decode a Codable payload, set attributeRules.\(entityName).\(attribute.name).swiftType and storageMethod 'codable'."
            )
          )
        }

        if attribute.attributeType == .transformableAttributeType {
          diagnostics.append(
            .init(
              severity: .note,
              code: nil,
              message:
                "bootstrap-config emitted a transformable placeholder for '\(entityName).\(attribute.name)'. Fill in swiftType and confirm transformerName before generate/validate.",
              hint: attribute.valueTransformerName == nil
                ? "Set attributeRules.\(entityName).\(attribute.name).transformerName if this field should use a specific ValueTransformer."
                : nil
            )
          )
        }

      }
    }

    return diagnostics
  }
}

private final class ToolingCompositeSourceParser: NSObject, XMLParserDelegate {
  private var composites: [String: [String]] = [:]
  private var currentCompositeName: String?

  func parseCompositeDefinitions(from selectedSourceURL: URL) -> [String: [String]]? {
    guard selectedSourceURL.pathExtension == "xcdatamodel" else { return nil }
    guard let parser = XMLParser(contentsOf: selectedSourceURL.appendingPathComponent("contents"))
    else {
      return nil
    }

    parser.delegate = self
    guard parser.parse() else { return nil }
    return composites
  }

  func parser(
    _ parser: XMLParser,
    didStartElement elementName: String,
    namespaceURI: String?,
    qualifiedName qName: String?,
    attributes attributeDict: [String: String] = [:]
  ) {
    switch elementName {
    case "composite":
      currentCompositeName = attributeDict["name"]
      if let currentCompositeName {
        composites[currentCompositeName] = composites[currentCompositeName] ?? []
      }
    case "attribute":
      guard let currentCompositeName, let name = attributeDict["name"] else { return }
      composites[currentCompositeName, default: []].append(name)
    default:
      break
    }
  }

  func parser(
    _ parser: XMLParser,
    didEndElement elementName: String,
    namespaceURI: String?,
    qualifiedName qName: String?
  ) {
    if elementName == "composite" {
      currentCompositeName = nil
    }
  }
}
