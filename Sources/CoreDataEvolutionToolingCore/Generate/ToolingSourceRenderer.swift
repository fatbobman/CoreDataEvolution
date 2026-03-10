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

/// Renders macro-style Swift source from generation IR.
public enum ToolingSourceRenderer {
  public static func renderSources(
    from modelIR: ToolingModelIR,
    moduleName: String = "AppModels",
    header: String? = nil
  ) throws -> [ToolingGeneratedSource] {
    if modelIR.generationPolicy.singleFile {
      return [
        .init(
          entityName: moduleName,
          suggestedFileName: "\(moduleName)+CoreDataEvolution.swift",
          contents: try renderModuleSource(
            modelIR.entities,
            generationPolicy: modelIR.generationPolicy,
            header: header
          )
        )
      ]
    }

    return try modelIR.entities.map { entity in
      .init(
        entityName: entity.name,
        suggestedFileName: "\(entity.name)+CoreDataEvolution.swift",
        contents: try renderEntitySource(
          entity,
          generationPolicy: modelIR.generationPolicy,
          header: header
        )
      )
    }
  }

  /// Renders one-time companion extension stubs for developer-authored methods and computed
  /// properties.
  ///
  /// These files are intentionally not tooling-managed after creation so exact validation can keep
  /// generated files unchanged while developers extend entities in separate files.
  public static func renderExtensionStubs(
    from modelIR: ToolingModelIR,
    header: String? = nil,
    enabled: Bool
  ) -> [ToolingGeneratedSource] {
    guard enabled else { return [] }

    return modelIR.entities.map { entity in
      .init(
        entityName: entity.name,
        suggestedFileName: "\(entity.name)+Extensions.swift",
        management: .companionStub,
        contents: renderExtensionStub(
          for: entity,
          header: header
        )
      )
    }
  }

  private static func renderModuleSource(
    _ entities: [ToolingEntityIR],
    generationPolicy: ToolingGenerationPolicyIR,
    header: String?
  ) throws -> String {
    var lines = renderFilePrelude(header: header)

    for (index, entity) in entities.enumerated() {
      if index > 0 {
        lines.append("")
      }
      lines.append(
        contentsOf: try renderEntityDeclaration(
          entity,
          generationPolicy: generationPolicy
        )
      )
    }

    return lines.joined(separator: "\n")
  }

  private static func renderEntitySource(
    _ entity: ToolingEntityIR,
    generationPolicy: ToolingGenerationPolicyIR,
    header: String?
  ) throws -> String {
    var lines = renderFilePrelude(header: header)
    lines.append(
      contentsOf: try renderEntityDeclaration(
        entity,
        generationPolicy: generationPolicy
      )
    )
    return lines.joined(separator: "\n")
  }

  private static func renderFilePrelude(header: String?) -> [String] {
    var lines: [String] = []
    if let header, header.isEmpty == false {
      lines.append(header.trimmingCharacters(in: .whitespacesAndNewlines))
      lines.append("")
    }
    lines.append("import CoreDataEvolution")
    lines.append("import Foundation")
    lines.append("")
    return lines
  }

  private static func renderExtensionStub(
    for entity: ToolingEntityIR,
    header: String?
  ) -> String {
    var lines = renderFilePrelude(header: header)
    lines.append("// Add methods and computed properties in this hand-written extension file.")
    lines.append("")
    lines.append("extension \(entity.name) {")
    lines.append("  // Example:")
    lines.append(
      "  // var displayTitle: String { \(entity.name.lowercased())SpecificDisplayTitle() }")
    lines.append("  // func configureForUI() {}")
    lines.append("}")
    return lines.joined(separator: "\n")
  }

  private static func renderEntityDeclaration(
    _ entity: ToolingEntityIR,
    generationPolicy: ToolingGenerationPolicyIR
  ) throws -> [String] {
    var lines: [String] = []
    lines.append("@objc(\(entity.name))")
    lines.append(renderPersistentModelAttribute(generationPolicy))
    lines.append(
      "\(accessModifierPrefix(generationPolicy.accessLevel))final class \(entity.name): NSManagedObject {"
    )
    let compositionAttributesByPersistentName: [String: ToolingCompositionIR] = Dictionary(
      uniqueKeysWithValues: entity.compositions.compactMap { composition in
        guard let persistentField = composition.persistentFields.first else { return nil }
        return (persistentField, composition)
      }
    )
    for attribute in entity.attributes {
      if attribute.storage.method == .composition {
        if let composition = compositionAttributesByPersistentName[attribute.persistentName] {
          lines.append(
            contentsOf: try renderCompositionProperty(
              composition,
              backingAttribute: attribute,
              accessLevel: generationPolicy.accessLevel
            )
          )
        }
      } else {
        lines.append(
          contentsOf: try renderAttributeProperty(
            attribute,
            accessLevel: generationPolicy.accessLevel
          )
        )
      }
    }

    for relationship in entity.relationships {
      lines.append(
        contentsOf: try renderRelationshipProperty(
          relationship,
          accessLevel: generationPolicy.accessLevel
        )
      )
    }

    if generationPolicy.generateInit {
      let initLines = try renderGeneratedInitializer(
        entity: entity,
        compositionAttributesByPersistentName: compositionAttributesByPersistentName,
        accessLevel: generationPolicy.accessLevel
      )
      if initLines.isEmpty == false {
        lines.append(contentsOf: initLines)
      }
    }

    lines.append("}")
    return lines
  }

  private static func renderPersistentModelAttribute(
    _ generationPolicy: ToolingGenerationPolicyIR
  ) -> String {
    var arguments: [String] = []

    if generationPolicy.generateInit {
      arguments.append("generateInit: true")
    }

    guard arguments.isEmpty == false else {
      return "@PersistentModel"
    }

    if arguments.count == 1 {
      return "@PersistentModel(\(arguments[0]))"
    }

    return """
      @PersistentModel(
        \(arguments.joined(separator: ",\n  "))
      )
      """
  }

  private static func renderAttributeProperty(
    _ attribute: ToolingAttributeIR,
    accessLevel: ToolingAccessLevel
  ) throws -> [String] {
    var lines: [String] = []

    if let attributeMacro = renderAttributeMacro(for: attribute) {
      lines.append("  \(attributeMacro)")
    }

    let typeName = try requireRenderableType(for: attribute)
    let defaultValue = try renderDefaultValue(for: attribute)
    lines.append(
      "  \(memberAccessModifierPrefix(for: accessLevel))var \(attribute.swiftName): \(typeName) = \(defaultValue)"
    )
    lines.append("")
    return lines
  }

  private static func renderCompositionProperty(
    _ composition: ToolingCompositionIR,
    backingAttribute: ToolingAttributeIR,
    accessLevel: ToolingAccessLevel
  ) throws -> [String] {
    var lines: [String] = []

    let persistentName =
      backingAttribute.persistentName == composition.swiftName
      ? nil : backingAttribute.persistentName
    let macro = renderAttributeMacro(
      isUnique: backingAttribute.isUnique,
      isTransient: backingAttribute.isTransient,
      persistentName: persistentName,
      storageMethod: .composition,
      transformerName: nil,
      decodeFailurePolicy: nil
    )
    lines.append("  \(macro ?? "@Attribute(storageMethod: .composition)")")

    let typeName = backingAttribute.isOptional ? "\(composition.swiftType)?" : composition.swiftType
    let defaultValue = try renderDefaultValue(
      for: backingAttribute,
      storageMethod: .composition,
      isOptional: backingAttribute.isOptional
    )
    lines.append(
      "  \(memberAccessModifierPrefix(for: accessLevel))var \(composition.swiftName): \(typeName) = \(defaultValue)"
    )
    lines.append("")
    return lines
  }

  private static func renderRelationshipProperty(
    _ relationship: ToolingRelationshipIR,
    accessLevel: ToolingAccessLevel
  ) throws -> [String] {
    guard relationship.isOptional else {
      throw ToolingFailure.user(
        .configInvalid,
        """
        generate requires relationship '\(relationship.persistentName)' to be optional in the \
        Core Data model. Current CoreDataEvolution relationship generation only supports optional \
        relationships.
        """
      )
    }

    guard relationship.inverseRelationshipName != nil else {
      throw ToolingFailure.user(
        .configInvalid,
        """
        generate requires relationship '\(relationship.persistentName)' to declare an inverse \
        relationship in the Core Data model.
        """
      )
    }

    let typeName: String
    switch relationship.cardinality {
    case .toOne:
      let baseType = relationship.destinationEntityName ?? "NSManagedObject"
      typeName = "\(baseType)?"
    case .toManyUnordered:
      typeName = "Set<\(relationship.destinationEntityName ?? "NSManagedObject")>"
    case .toManyOrdered:
      typeName = "[\(relationship.destinationEntityName ?? "NSManagedObject")]"
    }

    var lines: [String] = []
    guard let inverseRelationshipName = relationship.inverseRelationshipName else {
      throw ToolingFailure.user(
        .configInvalid,
        "generate requires inverse metadata for relationship '\(relationship.persistentName)'."
      )
    }
    lines.append(
      "  \(renderRelationshipAnnotation(relationship, inverseRelationshipName: inverseRelationshipName))"
    )
    lines.append(
      "  \(memberAccessModifierPrefix(for: accessLevel))var \(relationship.swiftName): \(typeName)")
    lines.append("")
    return lines
  }

  private static func renderRelationshipAnnotation(
    _ relationship: ToolingRelationshipIR,
    inverseRelationshipName: String
  ) -> String {
    var arguments: [String] = []

    if relationship.persistentName != relationship.swiftName {
      arguments.append(#"persistentName: "\#(relationship.persistentName)""#)
    }

    arguments.append(#"inverse: "\#(inverseRelationshipName)""#)
    arguments.append("deleteRule: .\(relationship.deleteRule)")

    if relationship.minCount != defaultMinimumModelCount(for: relationship) {
      arguments.append("minimumModelCount: \(relationship.minCount)")
    }
    if relationship.maxCount != defaultMaximumModelCount(for: relationship) {
      arguments.append("maximumModelCount: \(relationship.maxCount)")
    }

    return "@Relationship(\(arguments.joined(separator: ", ")))"
  }

  private static func defaultMinimumModelCount(for relationship: ToolingRelationshipIR) -> Int {
    relationship.isOptional ? 0 : 1
  }

  private static func defaultMaximumModelCount(for relationship: ToolingRelationshipIR) -> Int {
    switch relationship.cardinality {
    case .toOne:
      return 1
    case .toManyUnordered, .toManyOrdered:
      return 0
    }
  }

  private static func renderGeneratedInitializer(
    entity: ToolingEntityIR,
    compositionAttributesByPersistentName: [String: ToolingCompositionIR],
    accessLevel: ToolingAccessLevel
  ) throws -> [String] {
    var parameters: [String] = []
    var assignments: [String] = []

    for attribute in entity.attributes {
      if attribute.storage.method == .composition {
        guard let composition = compositionAttributesByPersistentName[attribute.persistentName]
        else {
          continue
        }

        let typeName = attribute.isOptional ? "\(composition.swiftType)?" : composition.swiftType
        parameters.append("    \(composition.swiftName): \(typeName)")
        assignments.append("    self.\(composition.swiftName) = \(composition.swiftName)")
      } else {
        let typeName = try requireRenderableType(for: attribute)
        parameters.append("    \(attribute.swiftName): \(typeName)")
        assignments.append("    self.\(attribute.swiftName) = \(attribute.swiftName)")
      }
    }

    guard parameters.isEmpty == false else {
      return []
    }

    return [
      "  \(memberAccessModifierPrefix(for: accessLevel))convenience init(",
      parameters.joined(separator: ",\n"),
      "  ) {",
      "    self.init(entity: Self.entity(), insertInto: nil)",
      assignments.joined(separator: "\n"),
      "  }",
      "",
    ]
  }

  private static func renderAttributeMacro(
    for attribute: ToolingAttributeIR
  ) -> String? {
    let persistentName =
      attribute.persistentName == attribute.swiftName ? nil : attribute.persistentName
    return renderAttributeMacro(
      isUnique: attribute.isUnique,
      isTransient: attribute.isTransient,
      persistentName: persistentName,
      storageMethod: attribute.storage.method,
      transformerName: attribute.storage.transformerName,
      decodeFailurePolicy: attribute.storage.decodeFailurePolicy
    )
  }

  private static func renderAttributeMacro(
    isUnique: Bool,
    isTransient: Bool,
    persistentName: String?,
    storageMethod: ToolingAttributeStorageRule,
    transformerName: String?,
    decodeFailurePolicy: ToolingDecodeFailurePolicy?
  ) -> String? {
    assert(
      isTransient == false || storageMethod == .default,
      "transient attributes must use default storage in source generation"
    )

    var arguments: [String] = []

    if isUnique {
      arguments.append(".unique")
    }

    if isTransient {
      arguments.append(".transient")
    }

    if let persistentName {
      arguments.append(#"persistentName: "\#(persistentName)""#)
    }

    switch storageMethod {
    case .default:
      break
    case .raw:
      arguments.append("storageMethod: .raw")
    case .codable:
      arguments.append("storageMethod: .codable")
    case .composition:
      arguments.append("storageMethod: .composition")
    case .transformed:
      guard let transformerName else {
        arguments.append(#"storageMethod: .transformed(name: "MissingTransformer")"#)
        break
      }
      arguments.append(#"storageMethod: .transformed(name: "\#(transformerName)")"#)
    }

    if let decodeFailurePolicy {
      arguments.append("decodeFailurePolicy: .\(decodeFailurePolicy.rawValue)")
    }

    guard arguments.isEmpty == false else {
      return nil
    }

    return "@Attribute(\(arguments.joined(separator: ", ")))"
  }

  private static func requireRenderableType(
    for attribute: ToolingAttributeIR
  ) throws -> String {
    guard let swiftType = attribute.storage.swiftType else {
      throw ToolingFailure.user(
        .configInvalid,
        "generate could not resolve a Swift type for '\(attribute.persistentName)'."
      )
    }
    return swiftType
  }

  private static func renderDefaultValue(
    for attribute: ToolingAttributeIR
  ) throws -> String {
    if attribute.isOptional {
      return "nil"
    }

    guard attribute.storage.nonOptionalSwiftType != nil else {
      throw ToolingFailure.user(
        .configInvalid,
        "generate could not resolve a Swift type for non-optional '\(attribute.swiftName)'."
      )
    }

    return try renderDefaultValue(
      for: attribute,
      storageMethod: attribute.storage.method,
      isOptional: false
    )
  }

  // V1 generation follows model defaults exactly. It does not invent code-side defaults or convert
  // persistent defaults into custom storage values such as enums, codable payloads, or compositions.
  private static func renderDefaultValue(
    for attribute: ToolingAttributeIR,
    storageMethod: ToolingAttributeStorageRule,
    isOptional: Bool
  ) throws -> String {
    if isOptional {
      return "nil"
    }

    switch storageMethod {
    case .default:
      guard let modelDefaultValueLiteral = attribute.modelDefaultValueLiteral else {
        throw ToolingFailure.user(
          .configInvalid,
          """
          generate requires a model default value for non-optional default storage '\(attribute.swiftName)'.
          """
        )
      }
      return modelDefaultValueLiteral
    case .raw, .codable, .composition, .transformed:
      throw ToolingFailure.user(
        .configInvalid,
        """
        generate cannot derive a non-optional default for custom storage '\(storageMethod.rawValue)' \
        on '\(attribute.swiftName)'. Make the field optional or add a future explicit code-default \
        rule when that feature is supported.
        """
      )
    }
  }

  private static func accessModifierPrefix(_ accessLevel: ToolingAccessLevel) -> String {
    switch accessLevel {
    case .internal:
      return ""
    case .public:
      return "public "
    }
  }

  private static func memberAccessModifierPrefix(for accessLevel: ToolingAccessLevel) -> String {
    accessModifierPrefix(accessLevel)
  }

}
