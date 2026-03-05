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

/// Marker-only macro. It intentionally generates no peer declarations.
public enum IgnoreMacro: PeerMacro {
  public static func expansion(
    of _: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard let variable = declaration.as(VariableDeclSyntax.self) else {
      MacroDiagnosticReporter.error(
        "@Ignore can only be attached to a stored `var` property.",
        domain: "CoreDataEvolution.IgnoreMacro",
        in: context,
        node: declaration
      )
      return []
    }

    if variable.bindingSpecifier.tokenKind != .keyword(.var) {
      MacroDiagnosticReporter.error(
        "@Ignore can only be attached to a stored `var` property.",
        domain: "CoreDataEvolution.IgnoreMacro",
        in: context,
        node: variable
      )
      return []
    }

    if variable.modifiers.contains(where: { $0.name.text == "static" || $0.name.text == "class" }) {
      MacroDiagnosticReporter.error(
        "@Ignore only supports instance stored `var` properties.",
        domain: "CoreDataEvolution.IgnoreMacro",
        in: context,
        node: variable
      )
      return []
    }

    if variable.modifiers.contains(where: { $0.name.text == "lazy" }) {
      MacroDiagnosticReporter.error(
        "@Ignore does not support lazy properties.",
        domain: "CoreDataEvolution.IgnoreMacro",
        in: context,
        node: variable
      )
      return []
    }

    for binding in variable.bindings {
      if binding.accessorBlock != nil {
        MacroDiagnosticReporter.error(
          "@Ignore can only be attached to a stored `var` property.",
          domain: "CoreDataEvolution.IgnoreMacro",
          in: context,
          node: binding
        )
        return []
      }
    }

    return []
  }
}
