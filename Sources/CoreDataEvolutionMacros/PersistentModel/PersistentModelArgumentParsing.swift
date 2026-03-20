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

func parsePersistentModelArguments(
  from node: AttributeSyntax,
  context: some MacroExpansionContext,
  emitDiagnostics: Bool = true
) -> PersistentModelArguments? {
  guard let list = node.arguments?.as(LabeledExprListSyntax.self) else {
    return PersistentModelArguments(generateInit: false, generateToManyCount: true)
  }

  var generateInit = false
  var generateToManyCount = true

  for argument in list {
    guard let label = argument.label?.text else { continue }
    switch label {
    case "generateInit":
      guard let bool = argument.expression.as(BooleanLiteralExprSyntax.self) else {
        if emitDiagnostics {
          MacroDiagnosticReporter.error(
            "@PersistentModel argument `generateInit` must be a boolean literal.",
            domain: persistentModelMacroDomain,
            in: context,
            node: argument.expression
          )
        }
        return nil
      }
      generateInit = bool.literal.text == "true"
    case "generateToManyCount":
      guard let bool = argument.expression.as(BooleanLiteralExprSyntax.self) else {
        if emitDiagnostics {
          MacroDiagnosticReporter.error(
            "@PersistentModel argument `generateToManyCount` must be a boolean literal.",
            domain: persistentModelMacroDomain,
            in: context,
            node: argument.expression
          )
        }
        return nil
      }
      generateToManyCount = bool.literal.text == "true"
    default:
      if emitDiagnostics {
        MacroDiagnosticReporter.error(
          "@PersistentModel has unknown argument label `\(label)`.",
          domain: persistentModelMacroDomain,
          in: context,
          node: argument
        )
      }
      return nil
    }
  }

  return PersistentModelArguments(
    generateInit: generateInit,
    generateToManyCount: generateToManyCount
  )
}
