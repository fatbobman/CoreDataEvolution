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

      if variable.attributes.isEmpty == false {
        MacroDiagnosticReporter.error(
          "@Composition does not support property wrappers or field attributes in v1.",
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
        let typeText = typeAnnotation.type.trimmedDescription
        let isOptional = isOptionalType(typeAnnotation.type)
        let decodeCastType = optionalWrappedTypeName(typeAnnotation.type) ?? typeText
        let defaultValueExpression =
          binding.initializer?.value.trimmedDescription
          ?? (isOptional ? "nil" : nil)
        fields.append(
          CompositionField(
            name: fieldName,
            typeName: typeText,
            decodeCastTypeName: decodeCastType,
            isOptional: isOptional,
            defaultValueExpression: defaultValueExpression
          )
        )
        fieldEntries.append(
          """
          "\(fieldName)": .init(swiftPath: ["\(fieldName)"], persistentPath: ["\(fieldName)"])
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
        "  let \(field.name) = dictionary[\"\(field.name)\"] as? \(field.decodeCastTypeName)")
    } else {
      lines.append(
        "  guard let \(field.name) = dictionary[\"\(field.name)\"] as? \(field.typeName) else { return nil }"
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
      lines.append("  if let \(field.name) { dictionary[\"\(field.name)\"] = \(field.name) }")
    } else {
      lines.append("  dictionary[\"\(field.name)\"] = \(field.name)")
    }
  }
  lines.append("  return dictionary")
  return lines.joined(separator: "\n")
}

private func makeRuntimeFieldBody(fields: [CompositionField]) -> String {
  fields.map { field in
    """
    .init(
      persistentName: "\(field.name)",
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
    return ".string"
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
