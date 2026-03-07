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

import Foundation
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
  guard let list = attribute.arguments?.as(LabeledExprListSyntax.self) else {
    return nil
  }

  var persistentName: String?
  for argument in list {
    guard let label = argument.label?.text else {
      if emitDiagnostics {
        MacroDiagnosticReporter.error(
          "@CompositionField only supports the `persistentName:` argument.",
          domain: "CoreDataEvolution.CompositionFieldMacro",
          in: context,
          node: argument
        )
      }
      return nil
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
            "@CompositionField argument `persistentName` must be a string literal or nil.",
            domain: "CoreDataEvolution.CompositionFieldMacro",
            in: context,
            node: argument.expression
          )
        }
        return nil
      }

      if let persistentName, isValidCompositionFieldMacroName(persistentName) == false {
        if emitDiagnostics {
          MacroDiagnosticReporter.error(
            "@CompositionField argument `persistentName` must be a valid Core Data attribute name (letters, numbers, underscore; cannot start with number).",
            domain: "CoreDataEvolution.CompositionFieldMacro",
            in: context,
            node: argument.expression
          )
        }
        return nil
      }
    default:
      if emitDiagnostics {
        MacroDiagnosticReporter.error(
          "@CompositionField only supports the `persistentName:` argument.",
          domain: "CoreDataEvolution.CompositionFieldMacro",
          in: context,
          node: argument
        )
      }
      return nil
    }
  }

  return persistentName
}

private func isValidCompositionFieldMacroName(_ name: String) -> Bool {
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
