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

    let entities = try swiftFiles.flatMap { fileURL in
      try parseEntities(in: fileURL)
    }

    return .init(
      sourceDirectory: sourceDirectoryURL.path,
      entities: entities.sorted {
        ($0.objcEntityName ?? $0.className, $0.filePath) < (
          $1.objcEntityName ?? $1.className, $1.filePath
        )
      }
    )
  }

  private static func parseEntities(in fileURL: URL) throws -> [ToolingSourceEntityIR] {
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
    let collector = ToolingSourceEntityCollector(filePath: fileURL.path)
    collector.walk(fileSyntax)
    if let failure = collector.failures.first {
      throw failure
    }
    return collector.entities
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

    let pathScope = ToolingValidationPathScope(include: include, exclude: exclude)
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
  private(set) var entities: [ToolingSourceEntityIR] = []
  private(set) var failures: [ToolingFailure] = []

  init(filePath: String) {
    self.filePath = filePath
    super.init(viewMode: .sourceAccurate)
  }

  override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
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
      isOptional: isOptional,
      defaultValueLiteral: binding.initializer?.value.trimmedDescription,
      isStored: binding.accessorBlock == nil,
      isStatic: variable.modifiers.contains(where: { ["static", "class"].contains($0.name.text) }),
      hasIgnore: firstAttribute(named: "Ignore", in: variable.attributes) != nil,
      attribute: firstAttribute(named: "Attribute", in: variable.attributes).map(
        parseAttributeAnnotation(from:)),
      inverse: firstAttribute(named: "Inverse", in: variable.attributes).flatMap(
        parseInverseAnnotation(from:)),
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
    return .init(
      generateInit: false,
      relationshipSetterPolicy: .none,
      relationshipCountPolicy: .none
    )
  }

  var generateInit = false
  var setterPolicy: ToolingRelationshipSetterPolicy = .none
  var countPolicy: ToolingRelationshipCountPolicy = .none

  for argument in list {
    guard let label = argument.label?.text else { continue }
    let raw = normalizedExpression(argument.expression)

    switch label {
    case "generateInit":
      generateInit = raw == "true"
    case "relationshipSetterPolicy":
      setterPolicy = parseRelationshipSetterPolicy(from: raw) ?? .none
    case "relationshipCountPolicy":
      countPolicy = parseRelationshipCountPolicy(from: raw) ?? .none
    default:
      continue
    }
  }

  return .init(
    generateInit: generateInit,
    relationshipSetterPolicy: setterPolicy,
    relationshipCountPolicy: countPolicy
  )
}

private func parseAttributeAnnotation(
  from attribute: AttributeSyntax
) -> ToolingSourceAttributeAnnotationIR {
  guard let list = attribute.arguments?.as(LabeledExprListSyntax.self) else {
    return .init(
      isUnique: false,
      isTransient: false,
      originalName: nil,
      storageMethod: nil,
      transformerType: nil,
      decodeFailurePolicy: nil
    )
  }

  var isUnique = false
  var isTransient = false
  var originalName: String?
  var storageMethod: ToolingAttributeStorageRule?
  var transformerType: String?
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
    case "originalName":
      originalName = parseStringLiteral(argument.expression)
    case "storageMethod":
      let storage = parseStorageMethod(from: raw)
      storageMethod = storage.method
      transformerType = storage.transformerType
    case "decodeFailurePolicy":
      decodeFailurePolicy = parseDecodeFailurePolicy(from: raw)
    default:
      continue
    }
  }

  return .init(
    isUnique: isUnique,
    isTransient: isTransient,
    originalName: originalName,
    storageMethod: storageMethod,
    transformerType: transformerType,
    decodeFailurePolicy: decodeFailurePolicy
  )
}

private func parseInverseAnnotation(
  from attribute: AttributeSyntax
) -> ToolingSourceInverseAnnotationIR? {
  guard let list = attribute.arguments?.as(LabeledExprListSyntax.self),
    list.count == 1,
    let argument = list.first,
    let propertyLiteral = argument.expression.as(StringLiteralExprSyntax.self),
    propertyLiteral.segments.count == 1,
    let segment = propertyLiteral.segments.first?.as(StringSegmentSyntax.self)
  else {
    return nil
  }

  let inversePropertyName = segment.content.text
  guard inversePropertyName.isEmpty == false else {
    return nil
  }
  return .init(
    inversePropertyName: inversePropertyName
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
  method: ToolingAttributeStorageRule?, transformerType: String?
) {
  switch raw {
  case ".default", "AttributeStorageMethod.default",
    "CoreDataEvolution.AttributeStorageMethod.default":
    return (.default, nil)
  case ".raw", "AttributeStorageMethod.raw", "CoreDataEvolution.AttributeStorageMethod.raw":
    return (.raw, nil)
  case ".codable", "AttributeStorageMethod.codable",
    "CoreDataEvolution.AttributeStorageMethod.codable":
    return (.codable, nil)
  case ".composition", "AttributeStorageMethod.composition",
    "CoreDataEvolution.AttributeStorageMethod.composition":
    return (.composition, nil)
  default:
    guard
      raw.hasPrefix(".transformed(") || raw.hasPrefix("AttributeStorageMethod.transformed(")
        || raw.hasPrefix("CoreDataEvolution.AttributeStorageMethod.transformed(")
    else {
      return (nil, nil)
    }
    guard let start = raw.firstIndex(of: "("), let end = raw.lastIndex(of: ")") else {
      return (.transformed, nil)
    }
    let inner = String(raw[raw.index(after: start)..<end])
    let transformerType = inner.hasSuffix(".self") ? String(inner.dropLast(5)) : inner
    return (.transformed, transformerType)
  }
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

private func parseRelationshipSetterPolicy(from raw: String) -> ToolingRelationshipSetterPolicy? {
  switch raw {
  case ".none", "RelationshipGenerationPolicy.none",
    "CoreDataEvolution.RelationshipGenerationPolicy.none":
    return ToolingRelationshipSetterPolicy.none
  case ".warning", "RelationshipGenerationPolicy.warning",
    "CoreDataEvolution.RelationshipGenerationPolicy.warning":
    return .warning
  case ".plain", "RelationshipGenerationPolicy.plain",
    "CoreDataEvolution.RelationshipGenerationPolicy.plain":
    return .plain
  default:
    return nil
  }
}

private func parseRelationshipCountPolicy(from raw: String) -> ToolingRelationshipCountPolicy? {
  switch raw {
  case ".none", "RelationshipGenerationPolicy.none",
    "CoreDataEvolution.RelationshipGenerationPolicy.none":
    return ToolingRelationshipCountPolicy.none
  case ".warning", "RelationshipGenerationPolicy.warning",
    "CoreDataEvolution.RelationshipGenerationPolicy.warning":
    return .warning
  case ".plain", "RelationshipGenerationPolicy.plain",
    "CoreDataEvolution.RelationshipGenerationPolicy.plain":
    return .plain
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
