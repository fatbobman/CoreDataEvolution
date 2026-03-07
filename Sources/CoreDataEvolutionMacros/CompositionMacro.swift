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
      extension \(type.trimmed): CoreDataEvolution.CDCompositionPathProviding, CoreDataEvolution.CDCompositionValueCodable {}
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
    var fields: [CompositionField] = []
    var fieldEntries: [String] = []
    var hasError = false

    for member in structDecl.memberBlock.members {
      guard let variable = member.decl.as(VariableDeclSyntax.self) else {
        continue
      }

      let compositionFieldAttribute = firstAttribute(
        named: "CompositionField",
        in: variable.attributes
      )

      if variable.modifiers.contains(where: { $0.name.text == "static" || $0.name.text == "class" })
      {
        MacroDiagnosticReporter.error(
          "@Composition only supports instance stored properties.",
          domain: "CoreDataEvolution.CompositionMacro",
          in: context,
          node: variable
        )
        hasError = true
      }

      if variable.modifiers.contains(where: { $0.name.text == "lazy" }) {
        MacroDiagnosticReporter.error(
          "@Composition does not support lazy stored properties.",
          domain: "CoreDataEvolution.CompositionMacro",
          in: context,
          node: variable
        )
        hasError = true
      }

      if hasUnsupportedCompositionFieldAttributes(variable.attributes) {
        MacroDiagnosticReporter.error(
          "@Composition only supports @CompositionField on stored fields in v1.",
          domain: "CoreDataEvolution.CompositionMacro",
          in: context,
          node: variable
        )
        hasError = true
      }

      if variable.bindingSpecifier.tokenKind != .keyword(.var) {
        MacroDiagnosticReporter.error(
          "@Composition only processes `var` stored properties.",
          domain: "CoreDataEvolution.CompositionMacro",
          in: context,
          node: variable
        )
        hasError = true
      }

      if compositionFieldAttribute != nil, variable.bindings.count != 1 {
        MacroDiagnosticReporter.error(
          "@CompositionField must be attached to a single stored property declaration.",
          domain: "CoreDataEvolution.CompositionMacro",
          in: context,
          node: variable
        )
        hasError = true
      }

      for binding in variable.bindings {
        guard let identifierPattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
          MacroDiagnosticReporter.error(
            "@Composition only supports simple identifier stored properties.",
            domain: "CoreDataEvolution.CompositionMacro",
            in: context,
            node: binding.pattern
          )
          hasError = true
          continue
        }

        guard let typeAnnotation = binding.typeAnnotation else {
          MacroDiagnosticReporter.error(
            "@Composition fields must declare an explicit type.",
            domain: "CoreDataEvolution.CompositionMacro",
            in: context,
            node: binding.pattern
          )
          hasError = true
          continue
        }

        if binding.accessorBlock != nil {
          MacroDiagnosticReporter.error(
            "@Composition does not support computed properties or observing accessors.",
            domain: "CoreDataEvolution.CompositionMacro",
            in: context,
            node: binding
          )
          hasError = true
          continue
        }

        guard isAllowedFieldType(typeAnnotation.type) else {
          MacroDiagnosticReporter.error(
            "@Composition field type is unsupported in v1. Allowed: \(coreDataPrimitiveTypeListDescription()).",
            domain: "CoreDataEvolution.CompositionMacro",
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
        fieldEntries.append(
          """
          "\(fieldName)": .init(swiftPath: ["\(fieldName)"], persistentPath: ["\(persistentName)"])
          """
        )
      }
    }

    if hasError {
      return []
    }

    let tableBody = fieldEntries.joined(separator: ",\n")
    let runtimeFieldBody = makeRuntimeFieldBody(fields: fields)
    let encodeBody = makeEncodeBody(fields: fields)
    let decodeBody = makeDecodeBody(fields: fields)
    let generated: DeclSyntax =
      """
      \(raw: accessModifier)static let __cdCompositionFieldTable: [String: CoreDataEvolution.CDCompositionFieldMeta] = [
      \(raw: tableBody)
      ]

      \(raw: accessModifier)static let __cdRuntimeCompositionFields: [CoreDataEvolution.CDRuntimeCompositionFieldSchema] = [
      \(raw: runtimeFieldBody)
      ]

      \(raw: accessModifier)static func __cdDecodeComposition(from dictionary: [String: Any]) -> Self? {
      \(raw: decodeBody)
      }

      \(raw: accessModifier)var __cdEncodeComposition: [String: Any] {
      \(raw: encodeBody)
      }
      """

    return [generated]
  }
}

private struct CompositionField {
  let name: String
  let persistentName: String
  let typeName: String
  let decodeCastTypeName: String
  let isOptional: Bool
  let defaultValueExpression: String?
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

private struct ParsedCompositionFieldDeclArguments {
  let persistentName: String?
}

private func parseCompositionFieldDeclArguments(
  from attribute: AttributeSyntax?,
  emitDiagnostics: Bool,
  context: some MacroExpansionContext
) -> ParsedCompositionFieldDeclArguments? {
  guard let attribute else {
    return .init(persistentName: nil)
  }
  guard let list = attribute.arguments?.as(LabeledExprListSyntax.self) else {
    return .init(persistentName: nil)
  }

  var persistentName: String?
  for argument in list {
    guard let label = argument.label?.text else {
      if emitDiagnostics {
        MacroDiagnosticReporter.error(
          "@CompositionField only supports the `persistentName:` argument.",
          domain: "CoreDataEvolution.CompositionMacro",
          in: context,
          node: argument
        )
      }
      return nil
    }

    switch label {
    case "persistentName":
      if let literal = argument.expression.as(StringLiteralExprSyntax.self),
        literal.segments.count == 1,
        let segment = literal.segments.first?.as(StringSegmentSyntax.self)
      {
        persistentName = segment.content.text
      } else if argument.expression.trimmedDescription == "nil" {
        persistentName = nil
      } else {
        if emitDiagnostics {
          MacroDiagnosticReporter.error(
            "@CompositionField argument `persistentName` must be a string literal or nil.",
            domain: "CoreDataEvolution.CompositionMacro",
            in: context,
            node: argument.expression
          )
        }
        return nil
      }

      if let persistentName, isValidCompositionFieldPersistentName(persistentName) == false {
        if emitDiagnostics {
          MacroDiagnosticReporter.error(
            "@CompositionField argument `persistentName` must be a valid Core Data attribute name (letters, numbers, underscore; cannot start with number).",
            domain: "CoreDataEvolution.CompositionMacro",
            in: context,
            node: argument.expression
          )
        }
        return nil
      }
    default:
      if emitDiagnostics {
        MacroDiagnosticReporter.error(
          "@CompositionField only supports the `persistentName:` argument.",
          domain: "CoreDataEvolution.CompositionMacro",
          in: context,
          node: argument
        )
      }
      return nil
    }
  }

  return .init(persistentName: persistentName)
}

private func isValidCompositionFieldPersistentName(_ name: String) -> Bool {
  guard name.isEmpty == false else {
    return false
  }
  let scalars = name.unicodeScalars
  guard let first = scalars.first else {
    return false
  }
  let letters = CharacterSet.letters
  let digits = CharacterSet.decimalDigits
  if letters.contains(first) == false && first != "_" {
    return false
  }
  for scalar in scalars.dropFirst() {
    if letters.contains(scalar) || digits.contains(scalar) || scalar == "_" {
      continue
    }
    return false
  }
  return true
}
