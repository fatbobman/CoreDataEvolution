//
//  ------------------------------------------------
//  Original project: CoreDataEvolution
//  Created on 2026/3/6 by Fatbobman(东坡肘子)
//  X: @fatbobman
//  Mastodon: @fatbobman@mastodon.social
//  GitHub: @fatbobman
//  Blog: https://fatbobman.com
//  ------------------------------------------------
//  Copyright © 2024-present Fatbobman. All rights reserved.

import SwiftSyntax
import SwiftSyntaxMacros

/// Marker-only macro. `@PersistentModel` consumes the inverse hint during relationship analysis.
public enum InverseMacro: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard let variable = declaration.as(VariableDeclSyntax.self) else {
      MacroDiagnosticReporter.error(
        "@Inverse can only be attached to a `var` property declaration.",
        domain: "CoreDataEvolution.InverseMacro",
        in: context,
        node: declaration
      )
      return []
    }

    if variable.bindingSpecifier.tokenKind != .keyword(.var) {
      MacroDiagnosticReporter.error(
        "@Inverse can only be attached to a stored `var` relationship property.",
        domain: "CoreDataEvolution.InverseMacro",
        in: context,
        node: variable
      )
      return []
    }

    if variable.modifiers.contains(where: { $0.name.text == "static" || $0.name.text == "class" }) {
      MacroDiagnosticReporter.error(
        "@Inverse only supports instance stored `var` relationship properties.",
        domain: "CoreDataEvolution.InverseMacro",
        in: context,
        node: variable
      )
      return []
    }

    if variable.modifiers.contains(where: { $0.name.text == "lazy" }) {
      MacroDiagnosticReporter.error(
        "@Inverse does not support lazy properties.",
        domain: "CoreDataEvolution.InverseMacro",
        in: context,
        node: variable
      )
      return []
    }

    for binding in variable.bindings {
      if binding.accessorBlock != nil {
        MacroDiagnosticReporter.error(
          "@Inverse can only be attached to a stored `var` relationship property.",
          domain: "CoreDataEvolution.InverseMacro",
          in: context,
          node: binding
        )
        return []
      }
    }

    switch parseInverseDeclArguments(node) {
    case .success:
      break
    case .failure(.invalidShape):
      MacroDiagnosticReporter.error(
        "@Inverse requires a string property name in the form @Inverse(\"property\").",
        domain: "CoreDataEvolution.InverseMacro",
        in: context,
        node: node
      )
      return []
    }

    return []
  }
}
