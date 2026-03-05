//
//  ------------------------------------------------
//  Original project: CoreDataEvolution
//  Created on 2026/3/5 by Fatbobman(东坡肘子)
//  X: @fatbobman
//  Mastodon: @fatbobman@mastodon.social
//  GitHub: @fatbobman
//  Blog: https://fatbobman.com
//  ------------------------------------------------
//  Copyright © 2024-present Fatbobman. All rights reserved.

import SwiftSyntax
import SwiftSyntaxMacros

public enum PersistentModelMacro {}

extension PersistentModelMacro: ExtensionMacro {
  public static func expansion(
    of _: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo _: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    guard declaration.as(ClassDeclSyntax.self) != nil else {
      return []
    }
    let decl: DeclSyntax =
      """
      extension \(type.trimmed): CoreDataEvolution.PersistentEntity {}
      """
    guard let ext = decl.as(ExtensionDeclSyntax.self) else {
      MacroDiagnosticReporter.error(
        "@PersistentModel failed to generate extension conformance.",
        domain: persistentModelMacroDomain,
        in: context,
        node: declaration
      )
      return []
    }
    return [ext]
  }
}

extension PersistentModelMacro: MemberAttributeMacro {
  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingAttributesFor member: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [AttributeSyntax] {
    guard declaration.as(ClassDeclSyntax.self) != nil else {
      return []
    }
    guard let variable = member.as(VariableDeclSyntax.self) else {
      return []
    }
    let arguments = parsePersistentModelArguments(
      from: node,
      context: context,
      emitDiagnostics: false
    )
    guard
      let attribute = autoAttachedAttribute(
        for: variable,
        relationshipSetterPolicy: arguments?.relationshipSetterPolicy ?? .none
      )
    else {
      return []
    }
    return [attribute]
  }
}

extension PersistentModelMacro: MemberMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    conformingTo _: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard let classDecl = declaration.as(ClassDeclSyntax.self) else {
      MacroDiagnosticReporter.error(
        "@PersistentModel can only be attached to a class declaration.",
        domain: persistentModelMacroDomain,
        in: context,
        node: declaration
      )
      return []
    }

    guard classDecl.inheritsFromNSManagedObject else {
      MacroDiagnosticReporter.error(
        "@PersistentModel type must inherit from NSManagedObject.",
        domain: persistentModelMacroDomain,
        in: context,
        node: classDecl
      )
      return []
    }

    guard
      let arguments = parsePersistentModelArguments(
        from: node,
        context: context
      )
    else {
      return []
    }

    let accessModifier = accessModifierText(from: declaration)
    let modelTypeName = classDecl.name.text
    let model = analyzePersistentModelProperties(in: classDecl)

    var members: [DeclSyntax] = []
    members.append(makeKeysDecl(accessModifier: accessModifier, model: model))
    members.append(
      makePathsDecl(
        accessModifier: accessModifier,
        modelTypeName: modelTypeName,
        model: model
      )
    )
    members.append(
      makePathRootDecl(
        accessModifier: accessModifier,
        modelTypeName: modelTypeName,
        model: model
      )
    )
    members.append(
      makePathEntryDecl(accessModifier: accessModifier)
    )
    members.append(
      makeFieldTableDecl(
        accessModifier: accessModifier,
        modelTypeName: modelTypeName,
        model: model
      )
    )

    if let initDecl = makeInitDecl(
      accessModifier: accessModifier,
      model: model,
      generateInit: arguments.generateInit
    ) {
      members.append(initDecl)
    }

    members += makeToManyHelpers(
      accessModifier: accessModifier,
      model: model,
      setterPolicy: arguments.relationshipSetterPolicy
    )
    return members
  }
}

// MARK: - Model Parsing

private let persistentModelMacroDomain = "CoreDataEvolution.PersistentModelMacro"

private struct PersistentModelArguments {
  let generateInit: Bool
  let relationshipSetterPolicy: ParsedRelationshipGenerationPolicy
  let relationshipCountPolicy: ParsedRelationshipGenerationPolicy
}

enum ParsedRelationshipGenerationPolicy: String {
  case none
  case warning
  case plain
}

private enum PersistentModelPropertyKind {
  case attribute(PersistentAttributeProperty)
  case relationship(PersistentRelationshipProperty)
}

private struct PersistentModelAnalysis {
  let properties: [PersistentModelPropertyKind]

  var attributes: [PersistentAttributeProperty] {
    properties.compactMap {
      if case .attribute(let value) = $0 { return value }
      return nil
    }
  }

  var relationships: [PersistentRelationshipProperty] {
    properties.compactMap {
      if case .relationship(let value) = $0 { return value }
      return nil
    }
  }
}

private struct PersistentAttributeProperty {
  let propertyName: String
  let typeName: String
  let persistentName: String
  let storageMethod: ParsedAttributeStorageMethod
  let defaultValueExpression: String?
}

private struct PersistentRelationshipProperty {
  enum Kind {
    case toOne
    case toManySet
    case toManyArray
  }

  let propertyName: String
  let targetTypeName: String
  let kind: Kind
}

private func analyzePersistentModelProperties(in classDecl: ClassDeclSyntax)
  -> PersistentModelAnalysis
{
  var properties: [PersistentModelPropertyKind] = []
  for member in classDecl.memberBlock.members {
    guard let variable = member.decl.as(VariableDeclSyntax.self) else {
      continue
    }
    if variable.bindingSpecifier.tokenKind != .keyword(.var) {
      continue
    }
    if variable.modifiers.contains(where: { $0.name.text == "static" || $0.name.text == "class" }) {
      continue
    }
    if variable.modifiers.contains(where: { $0.name.text == "lazy" }) {
      continue
    }
    if hasMarkerAttribute("Ignore", in: variable) {
      continue
    }

    for binding in variable.bindings {
      guard binding.accessorBlock == nil else {
        continue
      }
      guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self) else {
        continue
      }
      guard let typeAnnotation = binding.typeAnnotation else {
        continue
      }

      let propertyName = identifier.identifier.text
      let typeName = typeAnnotation.type.trimmedDescription
      let defaultValueExpression = binding.initializer?.value.trimmedDescription

      if hasMarkerAttribute("Attribute", in: variable),
        let attribute = firstAttribute(named: "Attribute", in: variable)
      {
        let parsed = parseAttributeDeclArguments(attribute)
        properties.append(
          .attribute(
            PersistentAttributeProperty(
              propertyName: propertyName,
              typeName: typeName,
              persistentName: parsed.originalName ?? propertyName,
              storageMethod: parsed.storageMethod ?? .default,
              defaultValueExpression: defaultValueExpression
                ?? optionalFallbackDefault(type: typeAnnotation.type)
            )
          )
        )
        continue
      }

      if let relationship = parseRelationshipProperty(
        propertyName: propertyName,
        type: typeAnnotation.type
      ) {
        properties.append(.relationship(relationship))
        continue
      }

      properties.append(
        .attribute(
          PersistentAttributeProperty(
            propertyName: propertyName,
            typeName: typeName,
            persistentName: propertyName,
            storageMethod: .default,
            defaultValueExpression: defaultValueExpression
              ?? optionalFallbackDefault(type: typeAnnotation.type)
          )
        )
      )
    }
  }
  return PersistentModelAnalysis(properties: properties)
}

private func autoAttachedAttribute(
  for variable: VariableDeclSyntax,
  relationshipSetterPolicy: ParsedRelationshipGenerationPolicy
) -> AttributeSyntax? {
  guard variable.bindingSpecifier.tokenKind == .keyword(.var) else {
    return nil
  }
  if hasMarkerAttribute("Ignore", in: variable)
    || hasMarkerAttribute("Attribute", in: variable)
    || hasMarkerAttribute("_CDRelationship", in: variable)
  {
    return nil
  }
  if variable.modifiers.contains(where: { $0.name.text == "static" || $0.name.text == "class" }) {
    return nil
  }
  if variable.modifiers.contains(where: { $0.name.text == "lazy" }) {
    return nil
  }

  for binding in variable.bindings {
    guard binding.accessorBlock == nil else {
      return nil
    }
    guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
      return nil
    }
    guard let typeAnnotation = binding.typeAnnotation else {
      return nil
    }
    if let relationship = parseRelationshipProperty(
      propertyName: pattern.identifier.text,
      type: typeAnnotation.type
    ) {
      if relationship.kind == .toManySet {
        return
          "@_CDRelationship(setterPolicy: \(raw: relationshipSetterPolicyExpression(relationshipSetterPolicy)), _fromPersistentModel: true)"
      } else {
        return "@_CDRelationship(_fromPersistentModel: true)"
      }
    }
  }

  return "@Attribute"
}

private func relationshipSetterPolicyExpression(_ policy: ParsedRelationshipGenerationPolicy)
  -> String
{
  switch policy {
  case .none:
    return ".none"
  case .warning:
    return ".warning"
  case .plain:
    return ".plain"
  }
}

private func parseRelationshipProperty(
  propertyName: String,
  type: TypeSyntax
) -> PersistentRelationshipProperty? {
  if let element = setElementTypeName(type) {
    return PersistentRelationshipProperty(
      propertyName: propertyName,
      targetTypeName: element,
      kind: .toManySet
    )
  }
  if let element = arrayElementTypeName(type) {
    return PersistentRelationshipProperty(
      propertyName: propertyName,
      targetTypeName: element,
      kind: .toManyArray
    )
  }
  if let wrapped = attributeOptionalWrappedTypeName(type) {
    let base = attributeNormalizedBaseTypeName(type) ?? wrapped
    if coreDataPrimitiveTypeNames.contains(base) == false {
      return PersistentRelationshipProperty(
        propertyName: propertyName,
        targetTypeName: wrapped,
        kind: .toOne
      )
    }
  }
  return nil
}

// MARK: - Member Generation

private func makeKeysDecl(
  accessModifier: String,
  model: PersistentModelAnalysis
) -> DeclSyntax {
  let attributes = model.attributes
  if attributes.isEmpty {
    return
      """
      \(raw: accessModifier)enum Keys: String {}
      """
  }
  let rows = attributes.map { attribute in
    "  case \(attribute.propertyName) = \"\(attribute.persistentName)\""
  }.joined(separator: "\n")
  return
    """
    \(raw: accessModifier)enum Keys: String {
    \(raw: rows)
    }
    """
}

private func makePathsDecl(
  accessModifier: String,
  modelTypeName: String,
  model: PersistentModelAnalysis
) -> DeclSyntax {
  var lines: [String] = []

  for attribute in model.attributes {
    lines.append(
      """
      static let \(attribute.propertyName) = CoreDataEvolution.CDPath<\(modelTypeName), \(attribute.typeName)>(
        swiftPath: ["\(attribute.propertyName)"],
        persistentPath: ["\(attribute.persistentName)"],
        storageMethod: \(storageMethodExpression(attribute.storageMethod))
      )
      """
    )
  }

  for relation in model.relationships {
    switch relation.kind {
    case .toOne:
      lines.append(
        """
        static let \(relation.propertyName) = CoreDataEvolution.CDToOneRelationPath<\(modelTypeName), \(relation.targetTypeName)>(
          swiftPath: ["\(relation.propertyName)"],
          persistentPath: ["\(relation.propertyName)"]
        )
        """
      )
    case .toManySet, .toManyArray:
      lines.append(
        """
        static let \(relation.propertyName) = CoreDataEvolution.CDToManyRelationPath<\(modelTypeName), \(relation.targetTypeName)>(
          swiftPath: ["\(relation.propertyName)"],
          persistentPath: ["\(relation.propertyName)"]
        )
        """
      )
    }
  }

  let body = lines.joined(separator: "\n\n")
  return
    """
    \(raw: accessModifier)enum Paths {
    \(raw: body)
    }
    """
}

private func makePathRootDecl(
  accessModifier: String,
  modelTypeName: String,
  model: PersistentModelAnalysis
) -> DeclSyntax {
  let props = model.attributes.map(\.propertyName) + model.relationships.map(\.propertyName)
  let impl = props.map { propertyName -> String in
    """
    var \(propertyName): \(pathTypeReference(for: propertyName, in: model, modelTypeName: modelTypeName)) {
      Paths.\(propertyName)
    }
    """
  }.joined(separator: "\n\n")

  if impl.isEmpty {
    return
      """
      \(raw: accessModifier)struct PathRoot: Sendable {}
      """
  }

  return
    """
    \(raw: accessModifier)struct PathRoot: Sendable {
    \(raw: impl)
    }
    """
}

private func pathTypeReference(
  for propertyName: String,
  in model: PersistentModelAnalysis,
  modelTypeName: String
) -> String {
  if let attribute = model.attributes.first(where: { $0.propertyName == propertyName }) {
    return "CoreDataEvolution.CDPath<\(modelTypeName), \(attribute.typeName)>"
  }
  if let relation = model.relationships.first(where: { $0.propertyName == propertyName }) {
    switch relation.kind {
    case .toOne:
      return "CoreDataEvolution.CDToOneRelationPath<\(modelTypeName), \(relation.targetTypeName)>"
    case .toManySet, .toManyArray:
      return "CoreDataEvolution.CDToManyRelationPath<\(modelTypeName), \(relation.targetTypeName)>"
    }
  }
  return "Never"
}

private func makePathEntryDecl(accessModifier: String) -> DeclSyntax {
  """
  \(raw: accessModifier)static var path: PathRoot {
    .init()
  }
  """
}

private func makeFieldTableDecl(
  accessModifier: String,
  modelTypeName: String,
  model: PersistentModelAnalysis
) -> DeclSyntax {
  var rows: [String] = []
  for attribute in model.attributes {
    let supportsStoreSort = supportsStoreSort(attribute.storageMethod)
    let kind = attribute.storageMethod == .composition ? ".composition" : ".attribute"
    rows.append(
      """
      "\(attribute.propertyName)": .init(
        kind: \(kind),
        swiftPath: ["\(attribute.propertyName)"],
        persistentPath: ["\(attribute.persistentName)"],
        storageMethod: \(storageMethodExpression(attribute.storageMethod)),
        supportsStoreSort: \(supportsStoreSort)
      )
      """
    )
  }
  for relation in model.relationships {
    rows.append(
      """
      "\(relation.propertyName)": .init(
        kind: .relationship,
        swiftPath: ["\(relation.propertyName)"],
        persistentPath: ["\(relation.propertyName)"],
        storageMethod: .default,
        supportsStoreSort: false,
        isToManyRelationship: \(relation.kind == .toManySet || relation.kind == .toManyArray)
      )
      """
    )
  }
  let literalBody = rows.joined(separator: ",\n")

  var mergeLines: [String] = []
  for relation in model.relationships {
    switch relation.kind {
    case .toOne:
      mergeLines.append(
        """
        table.merge(
          CoreDataEvolution.CDRelationshipTableBuilder.makeToOneFieldEntries(
            modelSwiftPathPrefix: ["\(relation.propertyName)"],
            modelPersistentPathPrefix: ["\(relation.propertyName)"],
            target: \(relation.targetTypeName).self
          ),
          uniquingKeysWith: { _, new in new }
        )
        """
      )
    case .toManySet, .toManyArray:
      mergeLines.append(
        """
        table.merge(
          CoreDataEvolution.CDRelationshipTableBuilder.makeToManyFieldEntries(
            modelSwiftPathPrefix: ["\(relation.propertyName)"],
            modelPersistentPathPrefix: ["\(relation.propertyName)"],
            target: \(relation.targetTypeName).self
          ),
          uniquingKeysWith: { _, new in new }
        )
        """
      )
    }
  }
  for attribute in model.attributes where attribute.storageMethod == .composition {
    mergeLines.append(
      """
      table.merge(
        CoreDataEvolution.CDCompositionTableBuilder.makeModelFieldEntries(
          modelSwiftPathPrefix: ["\(attribute.propertyName)"],
          modelPersistentPathPrefix: ["\(attribute.persistentName)"],
          composition: \(attribute.typeName).self
        ),
        uniquingKeysWith: { _, new in new }
      )
      """
    )
  }
  let mergeBlock = mergeLines.joined(separator: "\n")
  return
    """
    \(raw: accessModifier)static let __cdFieldTable: [String: CoreDataEvolution.CDFieldMeta] = {
      var table: [String: CoreDataEvolution.CDFieldMeta] = [
      \(raw: literalBody)
      ]
    \(raw: mergeBlock)
      return table
    }()
    """
}

private func makeInitDecl(
  accessModifier: String,
  model: PersistentModelAnalysis,
  generateInit: Bool
) -> DeclSyntax? {
  guard generateInit, model.attributes.isEmpty == false else {
    return nil
  }

  let parameters = model.attributes.map { attribute -> String in
    if let defaultValue = attribute.defaultValueExpression {
      return "\(attribute.propertyName): \(attribute.typeName) = \(defaultValue)"
    }
    return "\(attribute.propertyName): \(attribute.typeName)"
  }.joined(separator: ",\n")

  let assigns = model.attributes.map {
    "self.\($0.propertyName) = \($0.propertyName)"
  }.joined(separator: "\n")

  return
    """
    \(raw: accessModifier)convenience init(
      \(raw: parameters)
    ) {
      self.init(entity: Self.entity(), insertInto: nil)
    \(raw: assigns)
    }
    """
}

private func makeToManyHelpers(
  accessModifier: String,
  model: PersistentModelAnalysis,
  setterPolicy: ParsedRelationshipGenerationPolicy
) -> [DeclSyntax] {
  var result: [DeclSyntax] = []
  for relation in model.relationships {
    let key = relation.propertyName
    let type = relation.targetTypeName
    let suffix = uppercaseFirst(key)
    switch relation.kind {
    case .toOne:
      continue
    case .toManySet:
      result.append(
        """
        \(raw: accessModifier)func addTo\(raw: suffix)(_ value: \(raw: type)) {
          mutableSetValue(forKey: "\(raw: key)").add(value)
        }
        """
      )
      result.append(
        """
        \(raw: accessModifier)func removeFrom\(raw: suffix)(_ value: \(raw: type)) {
          mutableSetValue(forKey: "\(raw: key)").remove(value)
        }
        """
      )
      if setterPolicy != .none {
        let maybeDeprecated =
          setterPolicy == .warning
          ? "@available(*, deprecated, message: \"Bulk to-many setter may hide relationship mutation costs. Prefer add/remove helpers.\")\n"
          : ""
        result.append(
          """
          \(raw: maybeDeprecated)\(raw: accessModifier)func replace\(raw: suffix)(with values: Set<\(raw: type)>) {
            setValue(NSSet(set: values), forKey: "\(raw: key)")
          }
          """
        )
      }
    case .toManyArray:
      result.append(
        """
        \(raw: accessModifier)func addTo\(raw: suffix)(_ value: \(raw: type)) {
          mutableOrderedSetValue(forKey: "\(raw: key)").add(value)
        }
        """
      )
      result.append(
        """
        \(raw: accessModifier)func removeFrom\(raw: suffix)(_ value: \(raw: type)) {
          mutableOrderedSetValue(forKey: "\(raw: key)").remove(value)
        }
        """
      )
    }
  }
  return result
}

// MARK: - Argument Parsing

private func parsePersistentModelArguments(
  from node: AttributeSyntax,
  context: some MacroExpansionContext,
  emitDiagnostics: Bool = true
) -> PersistentModelArguments? {
  guard let list = node.arguments?.as(LabeledExprListSyntax.self) else {
    return PersistentModelArguments(
      generateInit: true,
      relationshipSetterPolicy: .none,
      relationshipCountPolicy: .none
    )
  }

  var generateInit = true
  var setter: ParsedRelationshipGenerationPolicy = .none
  var count: ParsedRelationshipGenerationPolicy = .none

  for argument in list {
    guard let label = argument.label?.text else { continue }
    switch label {
    case "generateInit":
      guard let bool = argument.expression.as(BooleanLiteralExprSyntax.self) else {
        if emitDiagnostics {
          MacroDiagnosticReporter.error(
            "@PersistentModel argument `generateInit` must be a boolean literal.",
            domain: persistentModelMacroDomain,
            in: context,
            node: argument.expression
          )
        }
        return nil
      }
      generateInit = bool.literal.text == "true"
    case "relationshipSetterPolicy":
      guard
        let policy = parseRelationshipPolicy(
          from: argument.expression.trimmedDescription.replacingOccurrences(of: " ", with: "")
        )
      else {
        if emitDiagnostics {
          MacroDiagnosticReporter.error(
            "@PersistentModel `relationshipSetterPolicy` only supports .none, .warning, .plain.",
            domain: persistentModelMacroDomain,
            in: context,
            node: argument.expression
          )
        }
        return nil
      }
      setter = policy
    case "relationshipCountPolicy":
      guard
        let policy = parseRelationshipPolicy(
          from: argument.expression.trimmedDescription.replacingOccurrences(of: " ", with: "")
        )
      else {
        if emitDiagnostics {
          MacroDiagnosticReporter.error(
            "@PersistentModel `relationshipCountPolicy` only supports .none, .warning, .plain.",
            domain: persistentModelMacroDomain,
            in: context,
            node: argument.expression
          )
        }
        return nil
      }
      count = policy
    default:
      if emitDiagnostics {
        MacroDiagnosticReporter.error(
          "@PersistentModel has unknown argument label `\(label)`.",
          domain: persistentModelMacroDomain,
          in: context,
          node: argument
        )
      }
      return nil
    }
  }

  return PersistentModelArguments(
    generateInit: generateInit,
    relationshipSetterPolicy: setter,
    relationshipCountPolicy: count
  )
}

private func parseRelationshipPolicy(
  from raw: String
) -> ParsedRelationshipGenerationPolicy? {
  switch raw {
  case ".none", "RelationshipGenerationPolicy.none",
    "CoreDataEvolution.RelationshipGenerationPolicy.none":
    return ParsedRelationshipGenerationPolicy.none
  case ".warning", "RelationshipGenerationPolicy.warning",
    "CoreDataEvolution.RelationshipGenerationPolicy.warning":
    return ParsedRelationshipGenerationPolicy.warning
  case ".plain", "RelationshipGenerationPolicy.plain",
    "CoreDataEvolution.RelationshipGenerationPolicy.plain":
    return ParsedRelationshipGenerationPolicy.plain
  default:
    return nil
  }
}

// MARK: - Attribute Helper Parsing

private struct ParsedAttributeDeclArguments {
  let originalName: String?
  let storageMethod: ParsedAttributeStorageMethod?
}

private func parseAttributeDeclArguments(_ attribute: AttributeSyntax)
  -> ParsedAttributeDeclArguments
{
  guard let list = attribute.arguments?.as(LabeledExprListSyntax.self) else {
    return ParsedAttributeDeclArguments(originalName: nil, storageMethod: nil)
  }
  var originalName: String?
  var storageMethod: ParsedAttributeStorageMethod?

  for argument in list {
    guard let label = argument.label?.text else { continue }
    switch label {
    case "originalName":
      if let literal = argument.expression.as(StringLiteralExprSyntax.self),
        literal.segments.count == 1,
        let segment = literal.segments.first?.as(StringSegmentSyntax.self)
      {
        originalName = segment.content.text
      }
    case "storageMethod":
      storageMethod = parseAttributeStorageMethod(
        from: argument.expression.trimmedDescription.replacingOccurrences(of: " ", with: "")
      )
    default:
      continue
    }
  }

  return ParsedAttributeDeclArguments(
    originalName: originalName,
    storageMethod: storageMethod
  )
}

private func parseAttributeStorageMethod(from raw: String) -> ParsedAttributeStorageMethod? {
  if raw == ".default"
    || raw == "AttributeStorageMethod.default"
    || raw == "CoreDataEvolution.AttributeStorageMethod.default"
  {
    return .default
  }
  if raw == ".raw"
    || raw == "AttributeStorageMethod.raw"
    || raw == "CoreDataEvolution.AttributeStorageMethod.raw"
  {
    return .raw
  }
  if raw == ".codable"
    || raw == "AttributeStorageMethod.codable"
    || raw == "CoreDataEvolution.AttributeStorageMethod.codable"
  {
    return .codable
  }
  if raw == ".composition"
    || raw == "AttributeStorageMethod.composition"
    || raw == "CoreDataEvolution.AttributeStorageMethod.composition"
  {
    return .composition
  }
  if raw.hasPrefix(".transformed(")
    || raw.hasPrefix("AttributeStorageMethod.transformed(")
    || raw.hasPrefix("CoreDataEvolution.AttributeStorageMethod.transformed(")
  {
    return .transformed("ValueTransformer")
  }
  return nil
}

private func storageMethodExpression(_ method: ParsedAttributeStorageMethod) -> String {
  switch method {
  case .default: return ".default"
  case .raw: return ".raw"
  case .codable: return ".codable"
  case .composition: return ".composition"
  case .transformed: return ".transformed"
  }
}

private func supportsStoreSort(_ method: ParsedAttributeStorageMethod) -> Bool {
  switch method {
  case .default, .raw:
    return true
  case .codable, .transformed, .composition:
    return false
  }
}

// MARK: - Syntax Helpers

private func firstAttribute(named name: String, in variable: VariableDeclSyntax) -> AttributeSyntax?
{
  variable.attributes
    .compactMap { $0.as(AttributeSyntax.self) }
    .first { attributeName(of: $0) == name }
}

private func hasMarkerAttribute(_ name: String, in variable: VariableDeclSyntax) -> Bool {
  firstAttribute(named: name, in: variable) != nil
}

private func attributeName(of attribute: AttributeSyntax) -> String {
  attribute.attributeName.trimmedDescription
    .split(separator: ".")
    .last
    .map(String.init) ?? attribute.attributeName.trimmedDescription
}

private func setElementTypeName(_ type: TypeSyntax) -> String? {
  guard let identifier = type.as(IdentifierTypeSyntax.self) else {
    return nil
  }
  guard identifier.name.text == "Set", let clause = identifier.genericArgumentClause else {
    return nil
  }
  guard clause.arguments.count == 1, let argument = clause.arguments.first else {
    return nil
  }
  return argument.argument.trimmedDescription
}

private func arrayElementTypeName(_ type: TypeSyntax) -> String? {
  if let arrayType = type.as(ArrayTypeSyntax.self) {
    return arrayType.element.trimmedDescription
  }
  guard let identifier = type.as(IdentifierTypeSyntax.self) else {
    return nil
  }
  guard identifier.name.text == "Array", let clause = identifier.genericArgumentClause else {
    return nil
  }
  guard clause.arguments.count == 1, let argument = clause.arguments.first else {
    return nil
  }
  return argument.argument.trimmedDescription
}

private func optionalFallbackDefault(type: TypeSyntax) -> String? {
  if attributeOptionalWrappedTypeName(type) != nil {
    return "nil"
  }
  return nil
}

private func uppercaseFirst(_ text: String) -> String {
  guard let first = text.first else { return text }
  return String(first).uppercased() + text.dropFirst()
}

extension ClassDeclSyntax {
  fileprivate var inheritsFromNSManagedObject: Bool {
    guard let inheritanceClause else {
      return false
    }
    for inherited in inheritanceClause.inheritedTypes {
      let text = inherited.type.trimmedDescription
      if text == "NSManagedObject" || text == "CoreData.NSManagedObject" {
        return true
      }
    }
    return false
  }
}
