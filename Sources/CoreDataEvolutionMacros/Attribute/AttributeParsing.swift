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

func buildAttributeInfo(
  from attribute: AttributeSyntax,
  declaration: some DeclSyntaxProtocol,
  emitDiagnostics: Bool,
  context: some MacroExpansionContext
) -> AttributeInfo? {
  let messages = StoredPropertyValidationMessages(
    nonVariableDeclaration: "@Attribute can only be attached to an instance stored `var` property.",
    notVar: "@Attribute can only be attached to an instance stored `var` property.",
    staticOrClass: "@Attribute only supports instance stored `var` properties.",
    lazy: "@Attribute does not support lazy properties.",
    multipleBindings: "@Attribute must be attached to a single property declaration.",
    computed: "@Attribute can only be attached to an instance stored `var` property.",
    nonIdentifierPattern: "@Attribute only supports simple identifier properties.",
    missingTypeAnnotation: "@Attribute property must declare an explicit type annotation."
  )

  let variable: VariableDeclSyntax
  switch validateStoredPropertyVariable(declaration) {
  case .success(let parsedVariable):
    variable = parsedVariable
  case .failure(let failure):
    if emitDiagnostics {
      emitStoredPropertyValidationFailure(
        failure,
        messages: messages,
        domain: attributeMacroDomain,
        in: context
      )
    }
    return nil
  }

  let parsedBinding: ValidatedStoredPropertyBinding
  switch validateSingleStoredPropertyBinding(in: variable) {
  case .success(let binding):
    parsedBinding = binding
  case .failure(let failure):
    if emitDiagnostics {
      emitStoredPropertyValidationFailure(
        failure,
        messages: messages,
        domain: attributeMacroDomain,
        in: context
      )
    }
    return nil
  }

  let binding = parsedBinding.binding
  let identifierPattern = parsedBinding.identifierPattern
  let typeAnnotation = parsedBinding.typeAnnotation

  guard
    let arguments = parseAttributeArguments(
      from: attribute,
      emitDiagnostics: emitDiagnostics,
      context: context
    )
  else {
    return nil
  }

  let propertyName = identifierPattern.identifier.text
  let persistentName = arguments.persistentName ?? propertyName
  let typeName = typeAnnotation.type.trimmedDescription
  let nonOptionalTypeName = attributeOptionalWrappedTypeName(typeAnnotation.type) ?? typeName
  let baseTypeName = normalizedBaseTypeName(typeAnnotation.type) ?? nonOptionalTypeName
  let isOptional = attributeOptionalWrappedTypeName(typeAnnotation.type) != nil
  let explicitDefaultValueExpression = binding.initializer?.value.trimmedDescription
  let defaultValueExpression = explicitDefaultValueExpression ?? (isOptional ? "nil" : nil)
  let storageMethod = arguments.storageMethod ?? .default
  let decodeFailurePolicy = arguments.decodeFailurePolicy
  let isUnique = arguments.traits.contains(.unique)
  let isTransient = arguments.traits.contains(.transient)

  if defaultValueExpression == nil {
    if emitDiagnostics {
      MacroDiagnosticReporter.error(
        "@Attribute non-optional properties must declare a default value.",
        domain: attributeMacroDomain,
        id: "missing-default-value",
        in: context,
        node: binding.pattern
      )
    }
    return nil
  }

  if isTransient && storageMethod != .default {
    if emitDiagnostics {
      MacroDiagnosticReporter.error(
        "@Attribute trait `.transient` only supports `.default` storage in v1.",
        domain: attributeMacroDomain,
        id: "transient-storage-unsupported",
        in: context,
        node: attribute
      )
    }
    return nil
  }

  if isTransient && isUnique {
    if emitDiagnostics {
      MacroDiagnosticReporter.error(
        "@Attribute trait `.transient` cannot be combined with `.unique`.",
        domain: attributeMacroDomain,
        id: "transient-unique-unsupported",
        in: context,
        node: attribute
      )
    }
    return nil
  }

  if storageMethod == .default && isAllowedDefaultAttributeType(typeAnnotation.type) == false {
    if emitDiagnostics {
      MacroDiagnosticReporter.error(
        "@Attribute with `.default` storage only supports primitive types (\(coreDataPrimitiveTypeListDescription())).",
        domain: attributeMacroDomain,
        id: "default-type-unsupported",
        in: context,
        node: typeAnnotation.type
      )
    }
    return nil
  }

  if storageMethod != .raw && storageMethod != .codable
    && isTransformedStorageMethod(storageMethod) == false
    && decodeFailurePolicy != nil
  {
    if emitDiagnostics {
      MacroDiagnosticReporter.error(
        "@Attribute argument `decodeFailurePolicy` is only supported for `.raw`, `.codable`, and `.transformed` storage methods.",
        domain: attributeMacroDomain,
        id: "unsupported-decode-failure-policy",
        in: context,
        node: attribute
      )
    }
    return nil
  }

  if storageMethod == .raw && coreDataPrimitiveTypeNames.contains(baseTypeName) {
    if emitDiagnostics {
      MacroDiagnosticReporter.error(
        "@Attribute storageMethod `.raw` requires a RawRepresentable type. Primitive types should use `.default`.",
        domain: attributeMacroDomain,
        id: "invalid-raw-type",
        in: context,
        node: typeAnnotation.type
      )
    }
    return nil
  }

  if storageMethod == .composition
    && (coreDataPrimitiveTypeNames.contains(baseTypeName) || baseTypeName == "[String:Any]")
  {
    if emitDiagnostics {
      MacroDiagnosticReporter.error(
        "@Attribute storageMethod `.composition` requires a @Composition struct type, not a primitive/dictionary type.",
        domain: attributeMacroDomain,
        id: "invalid-composition-type",
        in: context,
        node: typeAnnotation.type
      )
    }
    return nil
  }

  if isOptional == false,
    storageMethod == .codable || storageMethod == .composition
      || isTransformedStorageMethod(storageMethod)
  {
    if emitDiagnostics {
      MacroDiagnosticReporter.error(
        "@Attribute storageMethod `.\(storageMethodDiagnosticName(storageMethod))` currently requires an optional property. Only nil-backed defaults are supported for this storage method.",
        domain: attributeMacroDomain,
        id: "unsupported-nonoptional-custom-storage",
        in: context,
        node: typeAnnotation.type
      )
    }
    return nil
  }

  if let explicitDefaultValueExpression,
    explicitDefaultValueExpression != "nil",
    storageMethod == .codable || storageMethod == .composition
      || isTransformedStorageMethod(storageMethod)
  {
    if emitDiagnostics {
      let message =
        "@Attribute storageMethod `.\(storageMethodDiagnosticName(storageMethod))` only supports nil as an explicit default value. Use an optional property and omit the default or assign nil."
      if let initializerValue = binding.initializer?.value {
        MacroDiagnosticReporter.error(
          message,
          domain: attributeMacroDomain,
          id: "unsupported-custom-storage-default",
          in: context,
          node: initializerValue
        )
      } else {
        MacroDiagnosticReporter.error(
          message,
          domain: attributeMacroDomain,
          id: "unsupported-custom-storage-default",
          in: context,
          node: binding.pattern
        )
      }
    }
    return nil
  }

  return AttributeInfo(
    propertyName: propertyName,
    persistentName: persistentName,
    typeName: typeName,
    nonOptionalTypeName: nonOptionalTypeName,
    baseTypeName: baseTypeName,
    isOptional: isOptional,
    defaultValueExpression: defaultValueExpression,
    storageMethod: storageMethod,
    decodeFailurePolicy: decodeFailurePolicy,
    isUnique: isUnique,
    isTransient: isTransient
  )
}

private func storageMethodDiagnosticName(_ storageMethod: ParsedAttributeStorageMethod) -> String {
  switch storageMethod {
  case .default:
    return "default"
  case .raw:
    return "raw"
  case .codable:
    return "codable"
  case .composition:
    return "composition"
  case .transformed:
    return "transformed"
  }
}

private func parseAttributeArguments(
  from attribute: AttributeSyntax,
  emitDiagnostics: Bool,
  context: some MacroExpansionContext
) -> ParsedAttributeArguments? {
  guard let argumentList = attribute.arguments?.as(LabeledExprListSyntax.self) else {
    return ParsedAttributeArguments(
      traits: [],
      persistentName: nil,
      storageMethod: nil,
      decodeFailurePolicy: nil
    )
  }

  var traits: [ParsedAttributeTrait] = []
  var persistentName: String?
  var storageMethod: ParsedAttributeStorageMethod?
  var decodeFailurePolicy: ParsedAttributeDecodeFailurePolicy?

  for argument in argumentList {
    guard let label = argument.label?.text else {
      guard
        let trait = parseAttributeTrait(
          from: argument.expression,
          emitDiagnostics: emitDiagnostics,
          context: context
        )
      else {
        return nil
      }
      if traits.contains(trait) == false {
        traits.append(trait)
      }
      continue
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
            "@Attribute argument `persistentName` must be a string literal or nil.",
            domain: attributeMacroDomain,
            id: "invalid-persistent-name",
            in: context,
            node: argument.expression
          )
        }
        return nil
      }
      if let persistentName, isValidCoreDataAttributeName(persistentName) == false {
        if emitDiagnostics {
          MacroDiagnosticReporter.error(
            "@Attribute argument `\(label)` must be a valid Core Data attribute name (letters, numbers, underscore; cannot start with number).",
            domain: attributeMacroDomain,
            id: "invalid-persistent-name-format",
            in: context,
            node: argument.expression
          )
        }
        return nil
      }
    case "storageMethod":
      guard
        let parsedStorage = parseStorageMethod(
          from: argument.expression,
          emitDiagnostics: emitDiagnostics,
          context: context
        )
      else {
        return nil
      }
      storageMethod = parsedStorage
    case "decodeFailurePolicy":
      guard
        let parsedPolicy = parseDecodeFailurePolicy(
          from: argument.expression,
          emitDiagnostics: emitDiagnostics,
          context: context
        )
      else {
        return nil
      }
      decodeFailurePolicy = parsedPolicy
    default:
      if emitDiagnostics {
        MacroDiagnosticReporter.error(
          "@Attribute has unknown argument label `\(label)`.",
          domain: attributeMacroDomain,
          id: "unknown-argument",
          in: context,
          node: argument
        )
      }
      return nil
    }
  }

  return ParsedAttributeArguments(
    traits: traits,
    persistentName: persistentName,
    storageMethod: storageMethod,
    decodeFailurePolicy: decodeFailurePolicy
  )
}

private func parseAttributeTrait(
  from expression: ExprSyntax,
  emitDiagnostics: Bool,
  context: some MacroExpansionContext
) -> ParsedAttributeTrait? {
  let raw = expression.trimmedDescription.replacingOccurrences(of: " ", with: "")
  if raw == ".unique"
    || raw == "AttributeTrait.unique"
    || raw == "CoreDataEvolution.AttributeTrait.unique"
  {
    return .unique
  }

  if raw == ".transient"
    || raw == "AttributeTrait.transient"
    || raw == "CoreDataEvolution.AttributeTrait.transient"
  {
    return .transient
  }

  if emitDiagnostics {
    MacroDiagnosticReporter.error(
      "@Attribute only supports the `.unique` and `.transient` traits in unlabeled arguments.",
      domain: attributeMacroDomain,
      id: "unsupported-trait",
      in: context,
      node: expression
    )
  }
  return nil
}

private func isTransformedStorageMethod(_ storageMethod: ParsedAttributeStorageMethod) -> Bool {
  if case .transformed = storageMethod {
    return true
  }
  return false
}

private func isValidCoreDataAttributeName(_ name: String) -> Bool {
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

private func parseStorageMethod(
  from expression: ExprSyntax,
  emitDiagnostics: Bool,
  context: some MacroExpansionContext
) -> ParsedAttributeStorageMethod? {
  let raw = expression.trimmedDescription.replacingOccurrences(of: " ", with: "")

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
    guard
      let functionCall = expression.as(FunctionCallExprSyntax.self),
      functionCall.arguments.count == 1,
      let argument = functionCall.arguments.first
    else {
      if emitDiagnostics {
        MacroDiagnosticReporter.error(
          "@Attribute storageMethod `.transformed(...)` requires exactly one transformer type.",
          domain: attributeMacroDomain,
          id: "invalid-transformed",
          in: context,
          node: expression
        )
      }
      return nil
    }
    let transformer = argument.expression.trimmedDescription
    if transformer.hasSuffix(".self") == false {
      if emitDiagnostics {
        MacroDiagnosticReporter.error(
          "@Attribute storageMethod `.transformed(...)` requires a transformer metatype argument, for example `MyTransformer.self`.",
          domain: attributeMacroDomain,
          id: "invalid-transformed-argument",
          in: context,
          node: argument.expression
        )
      }
      return nil
    }
    return .transformed(transformer)
  }

  if emitDiagnostics {
    MacroDiagnosticReporter.error(
      "@Attribute storageMethod is unsupported. Allowed: .default, .raw, .codable, .transformed(...), .composition.",
      domain: attributeMacroDomain,
      id: "unsupported-storage-method",
      in: context,
      node: expression
    )
  }
  return nil
}

private func parseDecodeFailurePolicy(
  from expression: ExprSyntax,
  emitDiagnostics: Bool,
  context: some MacroExpansionContext
) -> ParsedAttributeDecodeFailurePolicy? {
  let raw = expression.trimmedDescription.replacingOccurrences(of: " ", with: "")
  if raw == ".fallbackToDefaultValue"
    || raw == "AttributeDecodeFailurePolicy.fallbackToDefaultValue"
    || raw == "CoreDataEvolution.AttributeDecodeFailurePolicy.fallbackToDefaultValue"
  {
    return .fallbackToDefaultValue
  }
  if raw == ".debugAssertNil"
    || raw == "AttributeDecodeFailurePolicy.debugAssertNil"
    || raw == "CoreDataEvolution.AttributeDecodeFailurePolicy.debugAssertNil"
  {
    return .debugAssertNil
  }

  if emitDiagnostics {
    MacroDiagnosticReporter.error(
      "@Attribute decodeFailurePolicy is unsupported. Allowed: .fallbackToDefaultValue, .debugAssertNil.",
      domain: attributeMacroDomain,
      id: "unsupported-decode-failure-policy-value",
      in: context,
      node: expression
    )
  }
  return nil
}
