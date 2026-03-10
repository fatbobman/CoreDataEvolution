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

/// Marker-only macro. `@Composition` consumes the persistent leaf name during field analysis.
public enum CompositionFieldMacro: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    let messages = StoredPropertyValidationMessages(
      nonVariableDeclaration:
        "@CompositionField can only be attached to a `var` property declaration.",
      notVar: "@CompositionField can only be attached to a stored `var` composition field.",
      staticOrClass: "@CompositionField only supports instance stored `var` fields.",
      lazy: "@CompositionField does not support lazy properties.",
      multipleBindings: "@CompositionField must be attached to a single property declaration.",
      computed: "@CompositionField can only be attached to a stored `var` composition field.",
      nonIdentifierPattern:
        "@CompositionField can only be attached to a stored `var` composition field.",
      missingTypeAnnotation:
        "@CompositionField can only be attached to a stored `var` composition field."
    )

    let variable: VariableDeclSyntax
    switch validateStoredPropertyVariable(declaration) {
    case .success(let parsedVariable):
      variable = parsedVariable
    case .failure(let failure):
      emitStoredPropertyValidationFailure(
        failure,
        messages: messages,
        domain: "CoreDataEvolution.CompositionFieldMacro",
        in: context
      )
      return []
    }

    switch validateSingleStoredPropertyBinding(in: variable) {
    case .success:
      break
    case .failure(let failure):
      emitStoredPropertyValidationFailure(
        failure,
        messages: messages,
        domain: "CoreDataEvolution.CompositionFieldMacro",
        in: context
      )
      return []
    }

    guard
      parseCompositionFieldArguments(node, emitDiagnostics: true, context: context) != nil
    else {
      return []
    }
    return []
  }
}

private func parseCompositionFieldArguments(
  _ attribute: AttributeSyntax,
  emitDiagnostics: Bool,
  context: some MacroExpansionContext
) -> String? {
  parseCompositionFieldDeclArguments(
    from: attribute,
    emitDiagnostics: emitDiagnostics,
    context: context
  )?.persistentName
}
