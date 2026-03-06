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

extension RelationshipMacro: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard
      let info = buildRelationshipInfo(
        from: node,
        declaration: declaration,
        context: context
      )
    else {
      return []
    }
    return makeRelationshipValidationPeers(from: info)
  }
}

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
  let kind: Kind
  let setterPolicy: ParsedRelationshipGenerationPolicy
}

private func buildRelationshipInfo(
  from attribute: AttributeSyntax,
  declaration: some DeclSyntaxProtocol,
  context: some MacroExpansionContext
) -> RelationshipInfo? {
  guard let variable = declaration.as(VariableDeclSyntax.self) else {
    MacroDiagnosticReporter.error(
      "@_CDRelationship can only be attached to an instance stored `var` relationship property.",
      domain: relationshipMacroDomain,
      in: context,
      node: declaration
    )
    return nil
  }

  guard variable.bindingSpecifier.tokenKind == .keyword(.var) else {
    MacroDiagnosticReporter.error(
      "@_CDRelationship can only be attached to an instance stored `var` relationship property.",
      domain: relationshipMacroDomain,
      in: context,
      node: variable
    )
    return nil
  }

  if variable.modifiers.contains(where: { $0.name.text == "static" || $0.name.text == "class" }) {
    MacroDiagnosticReporter.error(
      "@_CDRelationship only supports instance stored `var` properties.",
      domain: relationshipMacroDomain,
      in: context,
      node: variable
    )
    return nil
  }

  if variable.modifiers.contains(where: { $0.name.text == "lazy" }) {
    MacroDiagnosticReporter.error(
      "@_CDRelationship does not support lazy properties.",
      domain: relationshipMacroDomain,
      in: context,
      node: variable
    )
    return nil
  }

  guard variable.bindings.count == 1, let binding = variable.bindings.first else {
    MacroDiagnosticReporter.error(
      "@_CDRelationship must be attached to a single property declaration.",
      domain: relationshipMacroDomain,
      in: context,
      node: variable
    )
    return nil
  }

  if binding.accessorBlock != nil {
    MacroDiagnosticReporter.error(
      "@_CDRelationship can only be attached to an instance stored `var` relationship property.",
      domain: relationshipMacroDomain,
      in: context,
      node: binding
    )
    return nil
  }

  guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self) else {
    MacroDiagnosticReporter.error(
      "@_CDRelationship only supports simple identifier properties.",
      domain: relationshipMacroDomain,
      in: context,
      node: binding.pattern
    )
    return nil
  }

  guard let typeAnnotation = binding.typeAnnotation else {
    MacroDiagnosticReporter.error(
      "@_CDRelationship property must declare an explicit type annotation.",
      domain: relationshipMacroDomain,
      in: context,
      node: binding.pattern
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

  let propertyName = identifier.identifier.text
  let setterPolicy = arguments.setterPolicy
  guard
    let kind = parseRelationshipKind(
      from: typeAnnotation.type,
      context: context
    )
  else {
    return nil
  }

  return RelationshipInfo(
    propertyName: propertyName,
    kind: kind,
    setterPolicy: setterPolicy
  )
}

private struct ParsedRelationshipMacroArguments {
  let setterPolicy: ParsedRelationshipGenerationPolicy
  let fromPersistentModel: Bool
}

private func parseRelationshipMacroArguments(
  from node: AttributeSyntax
) -> ParsedRelationshipMacroArguments {
  guard let list = node.arguments?.as(LabeledExprListSyntax.self) else {
    return ParsedRelationshipMacroArguments(
      setterPolicy: ParsedRelationshipGenerationPolicy.none,
      fromPersistentModel: false
    )
  }
  var setterPolicy: ParsedRelationshipGenerationPolicy = .none
  var fromPersistentModel = false
  for argument in list {
    guard let label = argument.label?.text else {
      continue
    }
    if label == "setterPolicy" {
      setterPolicy =
        parseRelationshipGenerationPolicy(
          from: argument.expression.trimmedDescription.replacingOccurrences(of: " ", with: "")
        ) ?? .none
    } else if label == "_fromPersistentModel",
      let literal = argument.expression.as(BooleanLiteralExprSyntax.self)
    {
      fromPersistentModel = literal.literal.text == "true"
    }
  }
  return ParsedRelationshipMacroArguments(
    setterPolicy: setterPolicy,
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
  let key = info.propertyName

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
    var accessors: [AccessorDeclSyntax] = [
      """
      get {
        (value(forKey: "\(raw: key)") as? NSSet)?
          .compactMap { $0 as? \(raw: targetTypeName) }
          .reduce(into: Set<\(raw: targetTypeName)>()) { $0.insert($1) }
          ?? []
      }
      """
    ]

    if info.setterPolicy != .none {
      if info.setterPolicy == .warning {
        accessors.append(
          """
          @available(*, deprecated, message: "Bulk to-many setter may hide relationship mutation costs. Prefer add/remove helpers.")
          set {
            setValue(NSSet(set: newValue), forKey: "\(raw: key)")
          }
          """
        )
      } else {
        accessors.append(
          """
          set {
            setValue(NSSet(set: newValue), forKey: "\(raw: key)")
          }
          """
        )
      }
    }
    return accessors

  case .toManyArray(let targetTypeName):
    return [
      """
      get {
        (value(forKey: "\(raw: key)") as? NSOrderedSet)?
          .compactMap { $0 as? \(raw: targetTypeName) }
          ?? []
      }
      """
    ]
  }
}

private func makeRelationshipValidationPeers(from info: RelationshipInfo) -> [DeclSyntax] {
  let targetType: String
  switch info.kind {
  case .toOne(let targetTypeName), .toManySet(let targetTypeName), .toManyArray(let targetTypeName):
    targetType = targetTypeName
  }

  let memberName = "__cd_relationship_validate_\(info.propertyName)_entity"
  return [
    """
    private static let \(raw: memberName): Void = CoreDataEvolution._CDRelationshipMacroValidation.requirePersistentEntity(\(raw: targetType).self)
    """
  ]
}
