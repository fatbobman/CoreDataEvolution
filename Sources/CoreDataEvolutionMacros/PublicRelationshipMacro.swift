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
    let messages = StoredPropertyValidationMessages(
      nonVariableDeclaration: "@Relationship can only be attached to a `var` property declaration.",
      notVar: "@Relationship can only be attached to a stored `var` relationship property.",
      staticOrClass: "@Relationship only supports instance stored `var` relationship properties.",
      lazy: "@Relationship does not support lazy properties.",
      multipleBindings: "@Relationship must be attached to a single property declaration.",
      computed: "@Relationship can only be attached to a stored `var` relationship property.",
      nonIdentifierPattern: "@Relationship can only be attached to relationship properties.",
      missingTypeAnnotation: "@Relationship property must declare an explicit type annotation."
    )

    let variable: VariableDeclSyntax
    switch validateStoredPropertyVariable(declaration) {
    case .success(let parsedVariable):
      variable = parsedVariable
    case .failure(let failure):
      emitStoredPropertyValidationFailure(
        failure,
        messages: messages,
        domain: "CoreDataEvolution.PublicRelationshipMacro",
        in: context
      )
      return []
    }

    let parsedBinding: ValidatedStoredPropertyBinding
    switch validateSingleStoredPropertyBinding(in: variable) {
    case .success(let binding):
      parsedBinding = binding
    case .failure(let failure):
      emitStoredPropertyValidationFailure(
        failure,
        messages: messages,
        domain: "CoreDataEvolution.PublicRelationshipMacro",
        in: context
      )
      return []
    }

    guard parseRelationshipKindForPublicMacro(from: parsedBinding.typeAnnotation.type) != nil else {
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
        "@Relationship requires `inverse:` in the form @Relationship(persistentName: nil, inverse: \"property\", deleteRule: .nullify).",
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
        "@Relationship requires `deleteRule:` in the form @Relationship(persistentName: nil, inverse: \"property\", deleteRule: .nullify).",
        domain: "CoreDataEvolution.PublicRelationshipMacro",
        in: context,
        node: node
      )
      return []
    case .failure(.invalidMinimumModelCountArgument):
      MacroDiagnosticReporter.error(
        "@Relationship requires `minimumModelCount:` to be a non-negative integer literal.",
        domain: "CoreDataEvolution.PublicRelationshipMacro",
        in: context,
        node: node
      )
      return []
    case .failure(.invalidMaximumModelCountArgument):
      MacroDiagnosticReporter.error(
        "@Relationship requires `maximumModelCount:` to be a non-negative integer literal.",
        domain: "CoreDataEvolution.PublicRelationshipMacro",
        in: context,
        node: node
      )
      return []
    case .failure(.invalidShape):
      MacroDiagnosticReporter.error(
        "@Relationship must use the form @Relationship(persistentName: nil, inverse: \"property\", deleteRule: .nullify). Optional minimumModelCount/maximumModelCount may be added when needed.",
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
    return hasNamedRelationshipTargetType(wrappedType) ? .toOne : nil
  }
  if let elementType = setElementTypeName(type) {
    return hasNamedRelationshipTargetTypeName(elementType) ? .toManySet : nil
  }
  if let elementType = arrayElementTypeName(type) {
    return hasNamedRelationshipTargetTypeName(elementType) ? .toManyArray : nil
  }
  return nil
}

private enum CDRawRelationshipKind {
  case toOne
  case toManySet
  case toManyArray
}

private func hasNamedRelationshipTargetType(_ type: TypeSyntax) -> Bool {
  hasNamedRelationshipTargetTypeName(type.trimmedDescription)
}

// This public marker only needs to reject obviously non-relationship shapes. Deeper target
// validation still happens later in @PersistentModel / @_CDRelationship analysis.
private func hasNamedRelationshipTargetTypeName(_ name: String) -> Bool {
  let candidate = name.split(separator: ".").last.map(String.init) ?? name
  return candidate.isEmpty == false
}
