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
    guard let variable = declaration.as(VariableDeclSyntax.self) else {
      MacroDiagnosticReporter.error(
        "@CompositionField can only be attached to a `var` property declaration.",
        domain: "CoreDataEvolution.CompositionFieldMacro",
        in: context,
        node: declaration
      )
      return []
    }

    guard variable.bindingSpecifier.tokenKind == .keyword(.var) else {
      MacroDiagnosticReporter.error(
        "@CompositionField can only be attached to a stored `var` composition field.",
        domain: "CoreDataEvolution.CompositionFieldMacro",
        in: context,
        node: variable
      )
      return []
    }

    if variable.modifiers.contains(where: { $0.name.text == "static" || $0.name.text == "class" }) {
      MacroDiagnosticReporter.error(
        "@CompositionField only supports instance stored `var` fields.",
        domain: "CoreDataEvolution.CompositionFieldMacro",
        in: context,
        node: variable
      )
      return []
    }

    if variable.modifiers.contains(where: { $0.name.text == "lazy" }) {
      MacroDiagnosticReporter.error(
        "@CompositionField does not support lazy properties.",
        domain: "CoreDataEvolution.CompositionFieldMacro",
        in: context,
        node: variable
      )
      return []
    }

    guard variable.bindings.count == 1, let binding = variable.bindings.first else {
      MacroDiagnosticReporter.error(
        "@CompositionField must be attached to a single property declaration.",
        domain: "CoreDataEvolution.CompositionFieldMacro",
        in: context,
        node: variable
      )
      return []
    }

    if binding.accessorBlock != nil {
      MacroDiagnosticReporter.error(
        "@CompositionField can only be attached to a stored `var` composition field.",
        domain: "CoreDataEvolution.CompositionFieldMacro",
        in: context,
        node: binding
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
