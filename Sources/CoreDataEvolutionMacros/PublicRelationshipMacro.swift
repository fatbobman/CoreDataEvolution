//
//  ------------------------------------------------
//  Original project: CoreDataEvolution
//  Created on 2026/3/7 by Fatbobman(东坡肘子)
//  X: @fatbobman
//  Mastodon: @fatbobman@mastodon.social
//  GitHub: @fatbobman
//  Blog: https://fatbobman.com
//  ------------------------------------------------
//  Copyright © 2024-present Fatbobman. All rights reserved.

import SwiftSyntax
import SwiftSyntaxMacros

/// Marker-only macro. `@PersistentModel` consumes the relationship metadata during analysis.
public enum PublicRelationshipMacro: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard let variable = declaration.as(VariableDeclSyntax.self) else {
      MacroDiagnosticReporter.error(
        "@Relationship can only be attached to a `var` property declaration.",
        domain: "CoreDataEvolution.PublicRelationshipMacro",
        in: context,
        node: declaration
      )
      return []
    }

    guard variable.bindingSpecifier.tokenKind == .keyword(.var) else {
      MacroDiagnosticReporter.error(
        "@Relationship can only be attached to a stored `var` relationship property.",
        domain: "CoreDataEvolution.PublicRelationshipMacro",
        in: context,
        node: variable
      )
      return []
    }

    if variable.modifiers.contains(where: { $0.name.text == "static" || $0.name.text == "class" }) {
      MacroDiagnosticReporter.error(
        "@Relationship only supports instance stored `var` relationship properties.",
        domain: "CoreDataEvolution.PublicRelationshipMacro",
        in: context,
        node: variable
      )
      return []
    }

    if variable.modifiers.contains(where: { $0.name.text == "lazy" }) {
      MacroDiagnosticReporter.error(
        "@Relationship does not support lazy properties.",
        domain: "CoreDataEvolution.PublicRelationshipMacro",
        in: context,
        node: variable
      )
      return []
    }

    guard variable.bindings.count == 1, let binding = variable.bindings.first else {
      MacroDiagnosticReporter.error(
        "@Relationship must be attached to a single property declaration.",
        domain: "CoreDataEvolution.PublicRelationshipMacro",
        in: context,
        node: variable
      )
      return []
    }

    if binding.accessorBlock != nil {
      MacroDiagnosticReporter.error(
        "@Relationship can only be attached to a stored `var` relationship property.",
        domain: "CoreDataEvolution.PublicRelationshipMacro",
        in: context,
        node: binding
      )
      return []
    }

    guard let typeAnnotation = binding.typeAnnotation else {
      MacroDiagnosticReporter.error(
        "@Relationship property must declare an explicit type annotation.",
        domain: "CoreDataEvolution.PublicRelationshipMacro",
        in: context,
        node: binding.pattern
      )
      return []
    }

    guard parseRelationshipKindForPublicMacro(from: typeAnnotation.type) != nil else {
      MacroDiagnosticReporter.error(
        "@Relationship can only be attached to relationship properties.",
        domain: "CoreDataEvolution.PublicRelationshipMacro",
        in: context,
        node: variable
      )
      return []
    }

    switch parseRelationshipDeclArguments(node) {
    case .success:
      return []
    case .failure(.missingInverseArgument), .failure(.invalidInverseArgument):
      MacroDiagnosticReporter.error(
        "@Relationship requires `inverse:` in the form @Relationship(inverse: \"property\", deleteRule: .nullify).",
        domain: "CoreDataEvolution.PublicRelationshipMacro",
        in: context,
        node: node
      )
      return []
    case .failure(.unsupportedDeleteRuleArgument):
      MacroDiagnosticReporter.error(
        "@Relationship does not support `deleteRule: .noAction` in v1. Use `.nullify`, `.cascade`, or `.deny`.",
        domain: "CoreDataEvolution.PublicRelationshipMacro",
        in: context,
        node: node
      )
      return []
    case .failure(.missingDeleteRuleArgument), .failure(.invalidDeleteRuleArgument):
      MacroDiagnosticReporter.error(
        "@Relationship requires `deleteRule:` in the form @Relationship(inverse: \"property\", deleteRule: .nullify).",
        domain: "CoreDataEvolution.PublicRelationshipMacro",
        in: context,
        node: node
      )
      return []
    case .failure(.invalidShape):
      MacroDiagnosticReporter.error(
        "@Relationship must use the form @Relationship(inverse: \"property\", deleteRule: .nullify).",
        domain: "CoreDataEvolution.PublicRelationshipMacro",
        in: context,
        node: node
      )
      return []
    }
  }
}

private func parseRelationshipKindForPublicMacro(
  from type: TypeSyntax
) -> CDRawRelationshipKind? {
  if let wrappedType = optionalWrappedTypeSyntax(type) {
    return isManagedObjectLikeType(wrappedType) ? .toOne : nil
  }
  if let elementType = setElementTypeName(type) {
    return isManagedObjectLikeTypeName(elementType) ? .toManySet : nil
  }
  if let elementType = arrayElementTypeName(type) {
    return isManagedObjectLikeTypeName(elementType) ? .toManyArray : nil
  }
  return nil
}

private enum CDRawRelationshipKind {
  case toOne
  case toManySet
  case toManyArray
}

private func isManagedObjectLikeType(_ type: TypeSyntax) -> Bool {
  isManagedObjectLikeTypeName(type.trimmedDescription)
}

private func isManagedObjectLikeTypeName(_ name: String) -> Bool {
  let candidate = name.split(separator: ".").last.map(String.init) ?? name
  return candidate.isEmpty == false
}
