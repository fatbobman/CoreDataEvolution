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

struct ParsedCompositionFieldDeclArguments {
  let persistentName: String?
}

func parseCompositionFieldDeclArguments(
  from attribute: AttributeSyntax?,
  emitDiagnostics: Bool,
  context: some MacroExpansionContext
) -> ParsedCompositionFieldDeclArguments? {
  guard let attribute else {
    return .init(persistentName: nil)
  }

  guard let list = attribute.arguments?.as(LabeledExprListSyntax.self) else {
    return .init(persistentName: nil)
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

      if let persistentName, isValidCompositionFieldPersistentName(persistentName) == false {
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

  return .init(persistentName: persistentName)
}

func isValidCompositionFieldPersistentName(_ name: String) -> Bool {
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
