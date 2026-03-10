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

import Foundation
import SwiftSyntax
import SwiftSyntaxMacros

public enum CompositionMacro {}

private let compositionMacroDomain = "CoreDataEvolution.CompositionMacro"

private let compositionStoredFieldMessages = StoredPropertyValidationMessages(
  nonVariableDeclaration: "@Composition only supports instance stored properties.",
  notVar: "@Composition only processes `var` stored properties.",
  staticOrClass: "@Composition only supports instance stored properties.",
  lazy: "@Composition does not support lazy stored properties.",
  multipleBindings: "@CompositionField must be attached to a single stored property declaration.",
  computed: "@Composition does not support computed properties or observing accessors.",
  nonIdentifierPattern: "@Composition only supports simple identifier stored properties.",
  missingTypeAnnotation: "@Composition fields must declare an explicit type."
)

struct CompositionRenderingParts: Equatable {
  let fieldTableBody: String
  let pathBody: String
  let pathRootBody: String
  let runtimeFieldBody: String
  let encodeBody: String
  let decodeBody: String
}

extension CompositionMacro: ExtensionMacro {
  public static func expansion(
    of _: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo _: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    guard declaration.as(StructDeclSyntax.self) != nil else {
      return []
    }

    let decl: DeclSyntax =
      """
      extension \(type.trimmed): CoreDataEvolution.CDCompositionPathProviding, CoreDataEvolution.CDCompositionValueCodable, CoreDataEvolution.CoreDataPathDSLProviding {}
      """
    guard let ext = decl.as(ExtensionDeclSyntax.self) else {
      MacroDiagnosticReporter.error(
        "@Composition failed to generate extension conformance.",
        domain: "CoreDataEvolution.CompositionMacro",
        in: context,
        node: declaration
      )
      return []
    }
    return [ext]
  }
}

extension CompositionMacro: MemberMacro {
  public static func expansion(
    of _: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    conformingTo _: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard let structDecl = declaration.as(StructDeclSyntax.self) else {
      MacroDiagnosticReporter.error(
        "@Composition can only be attached to a struct.",
        domain: "CoreDataEvolution.CompositionMacro",
        in: context,
        node: declaration
      )
      return []
    }

    if structDecl.genericParameterClause != nil {
      MacroDiagnosticReporter.error(
        "@Composition does not support generic structs.",
        domain: "CoreDataEvolution.CompositionMacro",
        in: context,
        node: structDecl
      )
      return []
    }

    let accessModifier = accessModifierText(from: declaration)
    let fieldAnalysis = analyzeCompositionFields(
      in: structDecl,
      context: context
    )
    if fieldAnalysis.hasError {
      return []
    }
    let fields = fieldAnalysis.fields

    let compositionTypeName = structDecl.name.trimmedDescription
    let rendering = makeCompositionRenderingParts(
      accessModifier: accessModifier,
      compositionTypeName: compositionTypeName,
      fields: fields
    )
    let generated: DeclSyntax =
      """
      \(raw: accessModifier)static let __cdCompositionFieldTable: [String: CoreDataEvolution.CDCompositionFieldMeta] = [
      \(raw: rendering.fieldTableBody)
      ]

      \(raw: accessModifier)static let __cdFieldTable: [String: CoreDataEvolution.CDFieldMeta] = {
        CoreDataEvolution.CDCompositionTableBuilder.makeModelFieldEntries(
          modelSwiftPathPrefix: [],
          modelPersistentPathPrefix: [],
          composition: Self.self
        )
      }()

      \(raw: accessModifier)enum Paths {
      \(raw: rendering.pathBody)
      }

      \(raw: accessModifier)struct PathRoot: Sendable {
      \(raw: rendering.pathRootBody)
      }

      \(raw: accessModifier)static var path: PathRoot {
        .init()
      }

      \(raw: accessModifier)static let __cdRuntimeCompositionFields: [CoreDataEvolution.CDRuntimeCompositionFieldSchema] = [
      \(raw: rendering.runtimeFieldBody)
      ]

      \(raw: accessModifier)static func __cdDecodeComposition(from dictionary: [String: Any]) -> Self? {
      \(raw: rendering.decodeBody)
      }

      \(raw: accessModifier)var __cdEncodeComposition: [String: Any] {
      \(raw: rendering.encodeBody)
      }
      """

    return [generated]
  }
}

struct CompositionField: Equatable {
  let name: String
  let persistentName: String
  let typeName: String
  let decodeCastTypeName: String
  let isOptional: Bool
  let defaultValueExpression: String?
}

struct CompositionFieldAnalysis: Equatable {
  let fields: [CompositionField]
  let hasError: Bool
}

func analyzeCompositionFields(
  in structDecl: StructDeclSyntax,
  context: some MacroExpansionContext
) -> CompositionFieldAnalysis {
  var fields: [CompositionField] = []
  var hasError = false

  for member in structDecl.memberBlock.members {
    guard let variable = member.decl.as(VariableDeclSyntax.self) else {
      continue
    }

    let compositionFieldAttribute = firstAttribute(
      named: "CompositionField",
      in: variable.attributes
    )

    switch validateStoredPropertyVariable(variable) {
    case .success:
      break
    case .failure(let failure):
      emitStoredPropertyValidationFailure(
        failure,
        messages: compositionStoredFieldMessages,
        domain: compositionMacroDomain,
        in: context
      )
      hasError = true
      continue
    }

    if hasUnsupportedCompositionFieldAttributes(variable.attributes) {
      MacroDiagnosticReporter.error(
        "@Composition only supports @CompositionField on stored fields in v1.",
        domain: compositionMacroDomain,
        in: context,
        node: variable
      )
      hasError = true
    }

    if compositionFieldAttribute != nil, variable.bindings.count != 1 {
      emitStoredPropertyValidationFailure(
        .init(reason: .multipleBindings, node: Syntax(variable)),
        messages: compositionStoredFieldMessages,
        domain: compositionMacroDomain,
        in: context
      )
      hasError = true
    }

    for binding in variable.bindings {
      let parsedBinding: ValidatedStoredPropertyBinding
      switch validateStoredPropertyBinding(binding) {
      case .success(let validatedBinding):
        parsedBinding = validatedBinding
      case .failure(let failure):
        emitStoredPropertyValidationFailure(
          failure,
          messages: compositionStoredFieldMessages,
          domain: compositionMacroDomain,
          in: context
        )
        hasError = true
        continue
      }

      let identifierPattern = parsedBinding.identifierPattern
      let typeAnnotation = parsedBinding.typeAnnotation

      guard isAllowedFieldType(typeAnnotation.type) else {
        MacroDiagnosticReporter.error(
          "@Composition field type is unsupported in v1. Allowed: \(coreDataPrimitiveTypeListDescription()).",
          domain: compositionMacroDomain,
          in: context,
          node: typeAnnotation.type
        )
        hasError = true
        continue
      }

      let fieldName = identifierPattern.identifier.text
      let parsedCompositionField = parseCompositionFieldDeclArguments(
        from: compositionFieldAttribute,
        emitDiagnostics: true,
        context: context
      )
      if compositionFieldAttribute != nil, parsedCompositionField == nil {
        hasError = true
        continue
      }
      let persistentName = parsedCompositionField?.persistentName ?? fieldName
      let typeText = typeAnnotation.type.trimmedDescription
      let isOptional = isOptionalType(typeAnnotation.type)
      let decodeCastType = optionalWrappedTypeName(typeAnnotation.type) ?? typeText
      let defaultValueExpression =
        binding.initializer?.value.trimmedDescription
        ?? (isOptional ? "nil" : nil)
      fields.append(
        CompositionField(
          name: fieldName,
          persistentName: persistentName,
          typeName: typeText,
          decodeCastTypeName: decodeCastType,
          isOptional: isOptional,
          defaultValueExpression: defaultValueExpression
        )
      )
    }
  }

  return .init(fields: fields, hasError: hasError)
}

func makeCompositionRenderingParts(
  accessModifier: String,
  compositionTypeName: String,
  fields: [CompositionField]
) -> CompositionRenderingParts {
  .init(
    fieldTableBody: fields.map { field in
      """
      "\(field.name)": .init(swiftPath: ["\(field.name)"], persistentPath: ["\(field.persistentName)"])
      """
    }.joined(separator: ",\n"),
    pathBody: fields.map { field in
      """
      \(accessModifier)static let \(field.name) = CoreDataEvolution.CDPath<\(compositionTypeName), \(field.typeName)>(
        swiftPath: ["\(field.name)"],
        persistentPath: ["\(field.persistentName)"]
      )
      """
    }.joined(separator: "\n\n"),
    pathRootBody: fields.map { field in
      """
      \(accessModifier)var \(field.name): CoreDataEvolution.CDPath<\(compositionTypeName), \(field.typeName)> {
        Paths.\(field.name)
      }
      """
    }.joined(separator: "\n\n"),
    runtimeFieldBody: makeRuntimeFieldBody(fields: fields),
    encodeBody: makeEncodeBody(fields: fields),
    decodeBody: makeDecodeBody(fields: fields)
  )
}

private func makeDecodeBody(fields: [CompositionField]) -> String {
  var lines: [String] = []
  for field in fields {
    if field.isOptional {
      lines.append(
        "  let \(field.name) = dictionary[\"\(field.persistentName)\"] as? \(field.decodeCastTypeName)"
      )
    } else {
      lines.append(
        "  guard let \(field.name) = dictionary[\"\(field.persistentName)\"] as? \(field.typeName) else { return nil }"
      )
    }
  }

  if fields.isEmpty {
    lines.append("  return .init()")
    return lines.joined(separator: "\n")
  }

  let initArgs = fields.map { "\($0.name): \($0.name)" }.joined(separator: ", ")
  lines.append("  return .init(\(initArgs))")
  return lines.joined(separator: "\n")
}

private func makeEncodeBody(fields: [CompositionField]) -> String {
  var lines = ["  var dictionary: [String: Any] = [:]"]
  for field in fields {
    if field.isOptional {
      lines.append(
        "  if let \(field.name) { dictionary[\"\(field.persistentName)\"] = \(field.name) }"
      )
    } else {
      lines.append("  dictionary[\"\(field.persistentName)\"] = \(field.name)")
    }
  }
  lines.append("  return dictionary")
  return lines.joined(separator: "\n")
}

private func makeRuntimeFieldBody(fields: [CompositionField]) -> String {
  fields.map { field in
    """
    .init(
      persistentName: "\(field.persistentName)",
      swiftTypeName: "\(field.typeName)",
      primitiveType: \(runtimePrimitiveTypeExpression(typeName: field.decodeCastTypeName)),
      isOptional: \(field.isOptional),
      defaultValueExpression: \(runtimeDefaultValueExpression(field.defaultValueExpression))
    )
    """
  }.joined(separator: ",\n")
}

private func isAllowedFieldType(_ type: TypeSyntax) -> Bool {
  guard let base = normalizedBaseTypeName(type) else {
    return false
  }
  return coreDataPrimitiveTypeNames.contains(base)
}

private func runtimePrimitiveTypeExpression(typeName: String) -> String {
  switch typeName {
  case "String":
    return ".string"
  case "Bool":
    return ".bool"
  case "Int16":
    return ".int16"
  case "Int32":
    return ".int32"
  case "Int", "Int64":
    return ".int64"
  case "Float":
    return ".float"
  case "Double":
    return ".double"
  case "Decimal":
    return ".decimal"
  case "Date":
    return ".date"
  case "Data":
    return ".data"
  case "UUID":
    return ".uuid"
  case "URL":
    return ".url"
  default:
    return """
      ({
        #warning("Unsupported composition runtime primitive type '\(typeName)'. Falling back to .string.")
        return CoreDataEvolution.CDRuntimePrimitiveAttributeType.string
      }())
      """
  }
}

private func runtimeDefaultValueExpression(_ expression: String?) -> String {
  if let expression {
    return "\"\(escapeRuntimeLiteral(expression))\""
  }
  return "nil"
}

private func escapeRuntimeLiteral(_ text: String) -> String {
  text
    .replacingOccurrences(of: "\\", with: "\\\\")
    .replacingOccurrences(of: "\"", with: "\\\"")
}

private func isOptionalType(_ type: TypeSyntax) -> Bool {
  type.as(OptionalTypeSyntax.self) != nil
    || type.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) != nil
}

private func firstAttribute(named name: String, in attributes: AttributeListSyntax)
  -> AttributeSyntax?
{
  attributes.compactMap { $0.as(AttributeSyntax.self) }.first { attribute in
    compositionAttributeName(of: attribute) == name
  }
}

private func hasUnsupportedCompositionFieldAttributes(_ attributes: AttributeListSyntax) -> Bool {
  attributes.compactMap { $0.as(AttributeSyntax.self) }.contains { attribute in
    compositionAttributeName(of: attribute) != "CompositionField"
  }
}

private func compositionAttributeName(of attribute: AttributeSyntax) -> String {
  attribute.attributeName.trimmedDescription
    .split(separator: ".")
    .last
    .map(String.init) ?? attribute.attributeName.trimmedDescription
}
