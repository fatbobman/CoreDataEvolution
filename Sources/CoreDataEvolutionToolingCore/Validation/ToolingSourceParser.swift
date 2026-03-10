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
import SwiftParser
import SwiftSyntax

/// Parses developer-authored Swift source into a validate-friendly IR.
///
/// The parser only understands source inputs that matter to model drift validation. It does not
/// attempt to observe or reconstruct macro expansion output.
public enum ToolingSourceParser {
  public static func parse(
    sourceDirectory: String,
    include: [String] = [],
    exclude: [String] = [],
    fileManager: FileManager = .default
  ) throws -> ToolingSourceModelIR {
    let sourceDirectoryURL = URL(fileURLWithPath: sourceDirectory, isDirectory: true)
    var isDirectory: ObjCBool = false
    guard fileManager.fileExists(atPath: sourceDirectoryURL.path, isDirectory: &isDirectory),
      isDirectory.boolValue
    else {
      throw ToolingFailure.user(
        .sourceDirMissing,
        "source directory does not exist: '\(sourceDirectoryURL.path)'."
      )
    }

    let swiftFiles = try findSwiftFiles(
      in: sourceDirectoryURL,
      include: include,
      exclude: exclude,
      fileManager: fileManager
    )

    var entities: [ToolingSourceEntityIR] = []
    var transformerRegistrations: [String: String] = [:]
    for fileURL in swiftFiles {
      let parsed = try parseFile(in: fileURL)
      entities.append(contentsOf: parsed.entities)
      transformerRegistrations.merge(parsed.transformerRegistrations) { _, new in new }
    }

    return .init(
      sourceDirectory: sourceDirectoryURL.path,
      entities: entities.sorted {
        ($0.objcEntityName ?? $0.className, $0.filePath) < (
          $1.objcEntityName ?? $1.className, $1.filePath
        )
      },
      transformerRegistrations: transformerRegistrations
    )
  }

  private static func parseFile(in fileURL: URL) throws
    -> (entities: [ToolingSourceEntityIR], transformerRegistrations: [String: String])
  {
    let source: String
    do {
      source = try String(contentsOf: fileURL, encoding: .utf8)
    } catch {
      throw ToolingFailure.runtime(
        .ioFailed,
        "failed to read source file at '\(fileURL.path)' (\(error.localizedDescription))."
      )
    }

    let fileSyntax = Parser.parse(source: source)
    let collector = ToolingSourceEntityCollector(filePath: fileURL.path, source: source)
    collector.walk(fileSyntax)
    if let failure = collector.failures.first {
      throw failure
    }
    return (collector.entities, collector.transformerRegistrations)
  }

  private static func findSwiftFiles(
    in sourceDirectoryURL: URL,
    include: [String],
    exclude: [String],
    fileManager: FileManager
  ) throws -> [URL] {
    guard
      let enumerator = fileManager.enumerator(
        at: sourceDirectoryURL,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
      )
    else {
      return []
    }

    let pathScope = try ToolingValidationPathScope(include: include, exclude: exclude)
    var files: [URL] = []

    for case let fileURL as URL in enumerator {
      let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
      guard values.isRegularFile == true else { continue }
      guard fileURL.pathExtension == "swift" else { continue }

      let relativePath = fileURL.path.replacingOccurrences(
        of: sourceDirectoryURL.path + "/", with: "")
      if pathScope.contains(relativePath) == false {
        continue
      }
      files.append(fileURL)
    }

    return files.sorted(by: { $0.path < $1.path })
  }
}

private final class ToolingSourceEntityCollector: SyntaxVisitor {
  private let filePath: String
  private let source: String
  private(set) var entities: [ToolingSourceEntityIR] = []
  private(set) var transformerRegistrations: [String: String] = [:]
  private(set) var failures: [ToolingFailure] = []

  init(filePath: String, source: String) {
    self.filePath = filePath
    self.source = source
    super.init(viewMode: .sourceAccurate)
  }

  override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
    if let registration = parseTransformerRegistration(from: node) {
      transformerRegistrations[node.name.text] = registration
    }

    guard
      let persistentModelAttribute = firstAttribute(named: "PersistentModel", in: node.attributes)
    else {
      return .skipChildren
    }

    let properties = node.memberBlock.members.compactMap { member -> ToolingSourcePropertyIR? in
      guard let variable = member.decl.as(VariableDeclSyntax.self) else { return nil }
      recordUnsupportedMultiBinding(variable, className: node.name.text)
      return makeProperty(from: variable)
    }
    let customMembers = node.memberBlock.members.compactMap {
      member -> ToolingSourceCustomMemberIR? in
      if let function = member.decl.as(FunctionDeclSyntax.self) {
        return .init(
          filePath: filePath,
          name: function.name.text,
          kind: .function
        )
      }

      guard let variable = member.decl.as(VariableDeclSyntax.self) else { return nil }
      return makeCustomMember(from: variable)
    }

    entities.append(
      .init(
        filePath: filePath,
        className: node.name.text,
        objcEntityName: parseObjCName(from: node.attributes),
        persistentModelArguments: parsePersistentModelArguments(from: persistentModelAttribute),
        properties: properties,
        customMembers: customMembers
      )
    )
    return .skipChildren
  }

  private func makeProperty(from variable: VariableDeclSyntax) -> ToolingSourcePropertyIR? {
    guard variable.bindings.count == 1, let binding = variable.bindings.first,
      let identifier = binding.pattern.as(IdentifierPatternSyntax.self)
    else {
      return nil
    }

    let typeSyntax = binding.typeAnnotation?.type
    let typeName = typeSyntax?.trimmedDescription
    let nonOptionalTypeName = typeSyntax.flatMap(nonOptionalTypeName(from:))
    let isOptional = typeSyntax.map(isOptionalType(_:)) ?? false

    return .init(
      filePath: filePath,
      name: identifier.identifier.text,
      typeName: typeName,
      nonOptionalTypeName: nonOptionalTypeName,
      declarationRange: toolingTextRange(for: variable),
      declarationIndent: indentation(
        before: variable.positionAfterSkippingLeadingTrivia.utf8Offset),
      isOptional: isOptional,
      defaultValueLiteral: binding.initializer?.value.trimmedDescription,
      defaultValueRange: binding.initializer.map { toolingTextRange(for: $0.value) },
      isStored: binding.accessorBlock == nil,
      isStatic: variable.modifiers.contains(where: { ["static", "class"].contains($0.name.text) }),
      hasIgnore: firstAttribute(named: "Ignore", in: variable.attributes) != nil,
      attribute: firstAttribute(named: "Attribute", in: variable.attributes).map(
        parseAttributeAnnotation(from:)),
      relationship: firstAttribute(named: "Relationship", in: variable.attributes).flatMap(
        parseRelationshipAnnotation(from:)),
      relationshipShape: typeSyntax.flatMap(parseRelationshipShape(from:))
    )
  }

  private func makeCustomMember(from variable: VariableDeclSyntax) -> ToolingSourceCustomMemberIR? {
    guard variable.bindings.count == 1, let binding = variable.bindings.first,
      let identifier = binding.pattern.as(IdentifierPatternSyntax.self)
    else {
      return nil
    }

    guard binding.accessorBlock != nil else { return nil }

    return .init(
      filePath: filePath,
      name: identifier.identifier.text,
      kind: .computedProperty
    )
  }

  private func recordUnsupportedMultiBinding(_ variable: VariableDeclSyntax, className: String) {
    guard isPersistentModelStoredVariable(variable) else {
      return
    }
    guard variable.bindings.count > 1 else {
      return
    }
    failures.append(
      ToolingFailure.user(
        .validationFailed,
        """
        validate does not support declaring multiple stored properties in one `var` declaration inside @PersistentModel class '\(className)'. Split them into separate declarations.
        """
      )
    )
  }

  private func indentation(before utf8Offset: Int) -> String {
    let prefix = String(decoding: source.utf8.prefix(utf8Offset), as: UTF8.self)
    let lineStartIndex =
      prefix.lastIndex(of: "\n").map { prefix.index(after: $0) } ?? prefix.startIndex
    let linePrefix = String(prefix[lineStartIndex...])
    return String(linePrefix.prefix { $0 == " " || $0 == "\t" })
  }

  private func parseTransformerRegistration(from node: ClassDeclSyntax) -> String? {
    guard
      node.inheritanceClause?.inheritedTypes.contains(where: {
        let name = $0.type.trimmedDescription
        return name == "CDRegisteredValueTransformer"
          || name == "CoreDataEvolution.CDRegisteredValueTransformer"
      }) == true
    else {
      return nil
    }

    for member in node.memberBlock.members {
      guard let variable = member.decl.as(VariableDeclSyntax.self),
        variable.bindings.count == 1,
        let binding = variable.bindings.first,
        let identifier = binding.pattern.as(IdentifierPatternSyntax.self),
        identifier.identifier.text == "transformerName"
      else {
        continue
      }

      if let initializer = binding.initializer?.value,
        let name = parseTransformerRegistrationName(from: initializer)
      {
        return name
      }

      if let accessorBlock = binding.accessorBlock {
        if let name = parseComputedTransformerRegistrationName(from: accessorBlock) {
          return name
        }
      }
    }

    return nil
  }

  private func parseTransformerRegistrationName(from expression: ExprSyntax) -> String? {
    if let string = parseStringLiteral(expression) {
      return string
    }
    let raw = normalizedExpression(expression)
    if raw.hasPrefix("NSValueTransformerName(\""), raw.hasSuffix("\")") {
      return String(raw.dropFirst("NSValueTransformerName(\"".count).dropLast(2))
    }
    return nil
  }

  private func parseComputedTransformerRegistrationName(from accessorBlock: AccessorBlockSyntax)
    -> String?
  {
    guard case .accessors(let accessors) = accessorBlock.accessors else {
      return nil
    }
    guard
      let getter = accessors.first(where: {
        $0.accessorSpecifier.text == "get" || $0.accessorSpecifier.text.isEmpty
      })
    else {
      return nil
    }
    guard let body = getter.body else { return nil }
    for statement in body.statements {
      if let returnStmt = statement.item.as(ReturnStmtSyntax.self),
        let expression = returnStmt.expression
      {
        let raw = normalizedExpression(expression)
        if raw == ".secureUnarchiveFromDataTransformerName"
          || raw == "NSValueTransformerName.secureUnarchiveFromDataTransformerName"
        {
          return NSValueTransformerName.secureUnarchiveFromDataTransformerName.rawValue
        }
        if let parsed = parseTransformerRegistrationName(from: expression) {
          return parsed
        }
      }
    }
    return nil
  }
}

private func isPersistentModelStoredVariable(_ variable: VariableDeclSyntax) -> Bool {
  // Validate mirrors the macro-side restriction here so drift checks never silently skip a
  // persisted declaration shape that the macro pipeline rejects.
  guard variable.bindingSpecifier.tokenKind == .keyword(.var) else {
    return false
  }
  if variable.modifiers.contains(where: { ["static", "class"].contains($0.name.text) }) {
    return false
  }
  if variable.modifiers.contains(where: { $0.name.text == "lazy" }) {
    return false
  }
  return true
}

private func parsePersistentModelArguments(
  from attribute: AttributeSyntax
) -> ToolingSourcePersistentModelArgumentsIR {
  guard let list = attribute.arguments?.as(LabeledExprListSyntax.self) else {
    return .init(generateInit: false)
  }

  var generateInit = false

  for argument in list {
    guard let label = argument.label?.text else { continue }
    let raw = normalizedExpression(argument.expression)

    switch label {
    case "generateInit":
      generateInit = raw == "true"
    default:
      continue
    }
  }

  return .init(generateInit: generateInit)
}

private func parseAttributeAnnotation(
  from attribute: AttributeSyntax
) -> ToolingSourceAttributeAnnotationIR {
  guard let list = attribute.arguments?.as(LabeledExprListSyntax.self) else {
    return .init(
      range: toolingTextRange(for: attribute),
      isUnique: false,
      isTransient: false,
      persistentName: nil,
      storageMethod: nil,
      transformerName: nil,
      transformerTypeName: nil,
      decodeFailurePolicy: nil
    )
  }

  var isUnique = false
  var isTransient = false
  var persistentName: String?
  var storageMethod: ToolingAttributeStorageRule?
  var transformerName: String?
  var transformerTypeName: String?
  var decodeFailurePolicy: ToolingDecodeFailurePolicy?

  for argument in list {
    guard let label = argument.label?.text else {
      let raw = normalizedExpression(argument.expression)
      if raw == ".unique"
        || raw == "AttributeTrait.unique"
        || raw == "CoreDataEvolution.AttributeTrait.unique"
      {
        isUnique = true
      } else if raw == ".transient"
        || raw == "AttributeTrait.transient"
        || raw == "CoreDataEvolution.AttributeTrait.transient"
      {
        isTransient = true
      }
      continue
    }
    let raw = normalizedExpression(argument.expression)

    switch label {
    case "persistentName":
      persistentName = parseStringLiteral(argument.expression)
    case "storageMethod":
      let storage = parseStorageMethod(from: raw)
      storageMethod = storage.method
      transformerName = storage.transformerName
      transformerTypeName = storage.transformerTypeName
    case "decodeFailurePolicy":
      decodeFailurePolicy = parseDecodeFailurePolicy(from: raw)
    default:
      continue
    }
  }

  return .init(
    range: toolingTextRange(for: attribute),
    isUnique: isUnique,
    isTransient: isTransient,
    persistentName: persistentName,
    storageMethod: storageMethod,
    transformerName: transformerName,
    transformerTypeName: transformerTypeName,
    decodeFailurePolicy: decodeFailurePolicy
  )
}

private func parseRelationshipAnnotation(
  from attribute: AttributeSyntax
) -> ToolingSourceRelationshipAnnotationIR? {
  guard let list = attribute.arguments?.as(LabeledExprListSyntax.self) else {
    return nil
  }

  var inversePropertyName: String?
  var deleteRule: String?
  var minimumModelCount: Int?
  var maximumModelCount: Int?
  var persistentName: String?

  for argument in list {
    guard let label = argument.label?.text else {
      return nil
    }
    switch label {
    case "persistentName":
      persistentName = parseStringLiteral(argument.expression)
    case "inverse":
      inversePropertyName = parseStringLiteral(argument.expression)
    case "deleteRule":
      deleteRule = parseRelationshipDeleteRule(from: normalizedExpression(argument.expression))
    case "minimumModelCount":
      minimumModelCount = parseRelationshipCountLiteral(from: argument.expression)
    case "maximumModelCount":
      maximumModelCount = parseRelationshipCountLiteral(from: argument.expression)
    default:
      return nil
    }
  }

  guard let inversePropertyName, inversePropertyName.isEmpty == false, let deleteRule else {
    return nil
  }

  return .init(
    range: toolingTextRange(for: attribute),
    persistentName: persistentName,
    inversePropertyName: inversePropertyName,
    deleteRule: deleteRule,
    minimumModelCount: minimumModelCount,
    maximumModelCount: maximumModelCount
  )
}

private func parseRelationshipCountLiteral(from expression: ExprSyntax) -> Int? {
  guard let literal = expression.as(IntegerLiteralExprSyntax.self) else {
    return nil
  }
  guard let value = Int(literal.literal.text), value >= 0 else {
    return nil
  }
  return value
}

private func toolingTextRange(for syntax: some SyntaxProtocol) -> ToolingTextRange {
  .init(
    startUTF8Offset: syntax.positionAfterSkippingLeadingTrivia.utf8Offset,
    endUTF8Offset: syntax.endPositionBeforeTrailingTrivia.utf8Offset
  )
}

private func parseRelationshipShape(from type: TypeSyntax) -> ToolingSourceRelationshipShapeIR? {
  if setElementTypeName(from: type) != nil {
    return .toManyUnordered
  }
  if arrayElementTypeName(from: type) != nil {
    return .toManyOrdered
  }
  if optionalWrappedType(from: type) != nil {
    return .toOne
  }
  return nil
}

private func parseObjCName(from attributes: AttributeListSyntax) -> String? {
  guard
    let attribute = firstAttribute(named: "objc", in: attributes)
      ?? firstAttribute(named: "_objcRuntimeName", in: attributes),
    let arguments = attribute.arguments
  else {
    return nil
  }

  let text = arguments.trimmedDescription
  let normalized: String
  if text.hasPrefix("("), text.hasSuffix(")") {
    normalized = String(text.dropFirst().dropLast())
  } else {
    normalized = text
  }

  let trimmed = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
  if trimmed.hasPrefix("\""), trimmed.hasSuffix("\""), trimmed.count >= 2 {
    return String(trimmed.dropFirst().dropLast())
  }
  return trimmed.isEmpty ? nil : trimmed
}

private func firstAttribute(named name: String, in attributes: AttributeListSyntax)
  -> AttributeSyntax?
{
  attributes.compactMap { $0.as(AttributeSyntax.self) }.first { attributeName(of: $0) == name }
}

private func attributeName(of attribute: AttributeSyntax) -> String {
  attribute.attributeName.trimmedDescription
    .split(separator: ".")
    .last
    .map(String.init) ?? attribute.attributeName.trimmedDescription
}

private func normalizedExpression(_ expression: ExprSyntax) -> String {
  expression.trimmedDescription.replacingOccurrences(of: " ", with: "")
}

private func parseStringLiteral(_ expression: ExprSyntax) -> String? {
  guard let literal = expression.as(StringLiteralExprSyntax.self), literal.segments.count == 1,
    let segment = literal.segments.first?.as(StringSegmentSyntax.self)
  else {
    return nil
  }
  return segment.content.text
}

private func parseStorageMethod(from raw: String) -> (
  method: ToolingAttributeStorageRule?, transformerName: String?, transformerTypeName: String?
) {
  switch raw {
  case ".default", "AttributeStorageMethod.default",
    "CoreDataEvolution.AttributeStorageMethod.default":
    return (.default, nil, nil)
  case ".raw", "AttributeStorageMethod.raw", "CoreDataEvolution.AttributeStorageMethod.raw":
    return (.raw, nil, nil)
  case ".codable", "AttributeStorageMethod.codable",
    "CoreDataEvolution.AttributeStorageMethod.codable":
    return (.codable, nil, nil)
  case ".composition", "AttributeStorageMethod.composition",
    "CoreDataEvolution.AttributeStorageMethod.composition":
    return (.composition, nil, nil)
  default:
    return parseTransformedStorageMethod(from: raw)
  }
}

private func parseTransformedStorageMethod(from raw: String) -> (
  method: ToolingAttributeStorageRule?, transformerName: String?, transformerTypeName: String?
) {
  guard
    raw.hasPrefix(".transformed(") || raw.hasPrefix("AttributeStorageMethod.transformed(")
      || raw.hasPrefix("CoreDataEvolution.AttributeStorageMethod.transformed(")
  else {
    return (nil, nil, nil)
  }

  if let nameRange = raw.range(of: "name:\"") {
    let tail = raw[nameRange.upperBound...]
    guard let endQuote = tail.firstIndex(of: "\"") else {
      return (.transformed, nil, nil)
    }
    return (.transformed, String(tail[..<endQuote]), nil)
  }

  guard let start = raw.firstIndex(of: "("), let end = raw.lastIndex(of: ")") else {
    return (.transformed, nil, nil)
  }
  let inner = String(raw[raw.index(after: start)..<end])
  let transformerTypeName = inner.hasSuffix(".self") ? String(inner.dropLast(5)) : inner
  return (.transformed, nil, transformerTypeName)
}

private func parseDecodeFailurePolicy(from raw: String) -> ToolingDecodeFailurePolicy? {
  switch raw {
  case ".fallbackToDefaultValue", "AttributeDecodeFailurePolicy.fallbackToDefaultValue",
    "CoreDataEvolution.AttributeDecodeFailurePolicy.fallbackToDefaultValue":
    return .fallbackToDefaultValue
  case ".debugAssertNil", "AttributeDecodeFailurePolicy.debugAssertNil",
    "CoreDataEvolution.AttributeDecodeFailurePolicy.debugAssertNil":
    return .debugAssertNil
  default:
    return nil
  }
}

private func parseRelationshipDeleteRule(from raw: String) -> String? {
  switch raw {
  case ".nullify", "RelationshipDeleteRule.nullify",
    "CoreDataEvolution.RelationshipDeleteRule.nullify":
    return "nullify"
  case ".cascade", "RelationshipDeleteRule.cascade",
    "CoreDataEvolution.RelationshipDeleteRule.cascade":
    return "cascade"
  case ".deny", "RelationshipDeleteRule.deny", "CoreDataEvolution.RelationshipDeleteRule.deny":
    return "deny"
  default:
    return nil
  }
}

private func optionalWrappedType(from type: TypeSyntax) -> TypeSyntax? {
  if let optional = type.as(OptionalTypeSyntax.self) {
    return optional.wrappedType
  }
  if let implicitly = type.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
    return implicitly.wrappedType
  }
  return nil
}

private func nonOptionalTypeName(from type: TypeSyntax) -> String {
  optionalWrappedType(from: type)?.trimmedDescription ?? type.trimmedDescription
}

private func isOptionalType(_ type: TypeSyntax) -> Bool {
  optionalWrappedType(from: type) != nil
}

private func setElementTypeName(from type: TypeSyntax) -> String? {
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

private func arrayElementTypeName(from type: TypeSyntax) -> String? {
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
