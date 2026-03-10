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

public enum RelationshipMacro {}

extension RelationshipMacro: AccessorMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingAccessorsOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [AccessorDeclSyntax] {
    guard
      let info = buildRelationshipInfo(
        from: node,
        declaration: declaration,
        context: context
      )
    else {
      return []
    }
    return makeRelationshipAccessors(from: info)
  }
}

private let relationshipMacroDomain = "CoreDataEvolution.RelationshipMacro"

private struct RelationshipInfo {
  enum Kind {
    case toOne(targetTypeName: String)
    case toManySet(targetTypeName: String)
    case toManyArray(targetTypeName: String)
  }

  let propertyName: String
  let persistentName: String
  let kind: Kind
}

private func buildRelationshipInfo(
  from attribute: AttributeSyntax,
  declaration: some DeclSyntaxProtocol,
  context: some MacroExpansionContext
) -> RelationshipInfo? {
  let messages = StoredPropertyValidationMessages(
    nonVariableDeclaration:
      "@_CDRelationship can only be attached to an instance stored `var` relationship property.",
    notVar:
      "@_CDRelationship can only be attached to an instance stored `var` relationship property.",
    staticOrClass: "@_CDRelationship only supports instance stored `var` properties.",
    lazy: "@_CDRelationship does not support lazy properties.",
    multipleBindings: "@_CDRelationship must be attached to a single property declaration.",
    computed:
      "@_CDRelationship can only be attached to an instance stored `var` relationship property.",
    nonIdentifierPattern: "@_CDRelationship only supports simple identifier properties.",
    missingTypeAnnotation: "@_CDRelationship property must declare an explicit type annotation."
  )

  let variable: VariableDeclSyntax
  switch validateStoredPropertyVariable(declaration) {
  case .success(let parsedVariable):
    variable = parsedVariable
  case .failure(let failure):
    emitStoredPropertyValidationFailure(
      failure,
      messages: messages,
      domain: relationshipMacroDomain,
      in: context
    )
    return nil
  }

  let parsedBinding: ValidatedStoredPropertyBinding
  switch validateSingleStoredPropertyBinding(in: variable) {
  case .success(let binding):
    parsedBinding = binding
  case .failure(let failure):
    emitStoredPropertyValidationFailure(
      failure,
      messages: messages,
      domain: relationshipMacroDomain,
      in: context
    )
    return nil
  }

  let arguments = parseRelationshipMacroArguments(from: attribute)
  guard arguments.fromPersistentModel else {
    MacroDiagnosticReporter.error(
      "@_CDRelationship is internal and can only be used inside @PersistentModel types.",
      domain: relationshipMacroDomain,
      in: context,
      node: variable
    )
    return nil
  }

  let propertyName = parsedBinding.identifierPattern.identifier.text
  guard
    let kind = parseRelationshipKind(
      from: parsedBinding.typeAnnotation.type,
      context: context
    )
  else {
    return nil
  }

  return RelationshipInfo(
    propertyName: propertyName,
    persistentName: arguments.persistentName ?? propertyName,
    kind: kind
  )
}

private struct ParsedRelationshipMacroArguments {
  let persistentName: String?
  let fromPersistentModel: Bool
}

private func parseRelationshipMacroArguments(
  from node: AttributeSyntax
) -> ParsedRelationshipMacroArguments {
  guard let list = node.arguments?.as(LabeledExprListSyntax.self) else {
    return ParsedRelationshipMacroArguments(
      persistentName: nil,
      fromPersistentModel: false
    )
  }
  var persistentName: String?
  var fromPersistentModel = false
  for argument in list {
    guard let label = argument.label?.text else {
      continue
    }
    if label == "persistentName" {
      if argument.expression.trimmedDescription == "nil" {
        persistentName = nil
      } else if let literal = argument.expression.as(StringLiteralExprSyntax.self),
        literal.segments.count == 1,
        let segment = literal.segments.first?.as(StringSegmentSyntax.self)
      {
        persistentName = segment.content.text
      }
    } else if label == "_fromPersistentModel",
      let literal = argument.expression.as(BooleanLiteralExprSyntax.self)
    {
      fromPersistentModel = literal.literal.text == "true"
    }
  }
  return ParsedRelationshipMacroArguments(
    persistentName: persistentName,
    fromPersistentModel: fromPersistentModel
  )
}

private func parseRelationshipKind(
  from type: TypeSyntax,
  context: some MacroExpansionContext
) -> RelationshipInfo.Kind? {
  if let element = setElementTypeName(type) {
    return .toManySet(targetTypeName: element)
  }
  if let element = arrayElementTypeName(type) {
    return .toManyArray(targetTypeName: element)
  }
  if let wrapped = optionalWrappedTypeSyntax(type) {
    if setElementTypeName(wrapped) != nil
      || arrayElementTypeName(wrapped) != nil
    {
      MacroDiagnosticReporter.error(
        "To-many relationship properties must be non-optional (`Set<T>` or `[T]`).",
        domain: relationshipMacroDomain,
        in: context,
        node: type
      )
      return nil
    }
    return .toOne(targetTypeName: wrapped.trimmedDescription)
  }
  MacroDiagnosticReporter.error(
    "To-one relationship properties must be optional (`T?`). If this property is not a relationship, annotate it with @Attribute(storageMethod: ...).",
    domain: relationshipMacroDomain,
    in: context,
    node: type
  )
  return nil
}

private func makeRelationshipAccessors(from info: RelationshipInfo) -> [AccessorDeclSyntax] {
  let key = info.persistentName

  switch info.kind {
  case .toOne(let targetTypeName):
    return [
      """
      get {
        value(forKey: "\(raw: key)") as? \(raw: targetTypeName)
      }
      """,
      """
      set {
        setValue(newValue, forKey: "\(raw: key)")
      }
      """,
    ]

  case .toManySet(let targetTypeName):
    return [
      """
      get {
        // Expose a plain Swift Set<T> at the public API boundary.
        // This bridges and copies the underlying NSSet on every access.
        (value(forKey: "\(raw: key)") as? NSSet)?
          .compactMap { $0 as? \(raw: targetTypeName) }
          .reduce(into: Set<\(raw: targetTypeName)>()) { $0.insert($1) }
          ?? []
      }
      """
    ]

  case .toManyArray(let targetTypeName):
    return [
      """
      get {
        // Expose a plain Swift [T] at the public API boundary.
        // This bridges and copies the underlying NSOrderedSet on every access.
        (value(forKey: "\(raw: key)") as? NSOrderedSet)?
          .compactMap { $0 as? \(raw: targetTypeName) }
          ?? []
      }
      """
    ]
  }
}
