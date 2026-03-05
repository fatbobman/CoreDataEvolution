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
    return PersistentModelArguments(
      generateInit: false,
      relationshipSetterPolicy: .none,
      relationshipCountPolicy: .none
    )
  }

  var generateInit = false
  var setter: ParsedRelationshipGenerationPolicy = .none
  var count: ParsedRelationshipGenerationPolicy = .none

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
    case "relationshipSetterPolicy":
      guard
        let policy = parseRelationshipPolicy(
          from: argument.expression.trimmedDescription.replacingOccurrences(of: " ", with: "")
        )
      else {
        if emitDiagnostics {
          MacroDiagnosticReporter.error(
            "@PersistentModel `relationshipSetterPolicy` only supports .none, .warning, .plain.",
            domain: persistentModelMacroDomain,
            in: context,
            node: argument.expression
          )
        }
        return nil
      }
      setter = policy
    case "relationshipCountPolicy":
      guard
        let policy = parseRelationshipPolicy(
          from: argument.expression.trimmedDescription.replacingOccurrences(of: " ", with: "")
        )
      else {
        if emitDiagnostics {
          MacroDiagnosticReporter.error(
            "@PersistentModel `relationshipCountPolicy` only supports .none, .warning, .plain.",
            domain: persistentModelMacroDomain,
            in: context,
            node: argument.expression
          )
        }
        return nil
      }
      count = policy
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
    relationshipSetterPolicy: setter,
    relationshipCountPolicy: count
  )
}

private func parseRelationshipPolicy(
  from raw: String
) -> ParsedRelationshipGenerationPolicy? {
  switch raw {
  case ".none", "RelationshipGenerationPolicy.none",
    "CoreDataEvolution.RelationshipGenerationPolicy.none":
    return ParsedRelationshipGenerationPolicy.none
  case ".warning", "RelationshipGenerationPolicy.warning",
    "CoreDataEvolution.RelationshipGenerationPolicy.warning":
    return ParsedRelationshipGenerationPolicy.warning
  case ".plain", "RelationshipGenerationPolicy.plain",
    "CoreDataEvolution.RelationshipGenerationPolicy.plain":
    return ParsedRelationshipGenerationPolicy.plain
  default:
    return nil
  }
}
