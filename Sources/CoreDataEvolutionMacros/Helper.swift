//
//  ------------------------------------------------
//  Original project: CoreDataEvolution
//  Created on 2024/10/30 by Fatbobman(东坡肘子)
//  X: @fatbobman
//  Mastodon: @fatbobman@mastodon.social
//  GitHub: @fatbobman
//  Blog: https://fatbobman.com
//  ------------------------------------------------
//  Copyright © 2024-present Fatbobman. All rights reserved.

import Foundation
import SwiftDiagnostics
import SwiftSyntax
/// Determines whether to generate an initializer based on the attribute node.
///
/// This function checks the attribute node for an argument labeled "disableGenerateInit" with a boolean value.
/// If such an argument is found and its value is false, the function returns false, indicating that an initializer should not be generated.
/// Otherwise, it returns true, indicating that an initializer should be generated.
///
/// - Parameter node: The attribute node to check.
/// - Returns: A boolean indicating whether to generate an initializer.
import SwiftSyntaxMacros

func shouldGenerateInitializer(from node: AttributeSyntax) -> Bool {
  guard let argumentList = node.arguments?.as(LabeledExprListSyntax.self) else {
    return true  // Default to true if no arguments are present.
  }

  for argument in argumentList {
    if argument.label?.text == "disableGenerateInit",
      let booleanLiteral = argument.expression.as(BooleanLiteralExprSyntax.self)
    {
      return booleanLiteral.literal.text != "true"  // Return false if "disableGenerateInit" is set to true.
    }
  }
  return true  // Default to true if "disableGenerateInit" is not found or is set to false.
}

/// Returns explicit access modifier text with trailing space, or empty string for implicit internal.
func accessModifierText(from declaration: some DeclGroupSyntax) -> String {
  let accessLevels = ["open", "public", "package", "internal", "fileprivate", "private"]
  for access in accessLevels {
    if declaration.modifiers.contains(where: { $0.name.text == access }) {
      return "\(access) "
    }
  }
  return ""
}

/// Shared diagnostics emitter for macro implementations.
enum MacroDiagnosticReporter {
  static func error(
    _ message: String,
    domain: String,
    id: String = "invalid-declaration",
    in context: some MacroExpansionContext,
    node: some SyntaxProtocol
  ) {
    diagnose(
      message: message,
      severity: .error,
      domain: domain,
      id: id,
      in: context,
      node: node
    )
  }

  static func warning(
    _ message: String,
    domain: String,
    id: String = "warning",
    in context: some MacroExpansionContext,
    node: some SyntaxProtocol
  ) {
    diagnose(
      message: message,
      severity: .warning,
      domain: domain,
      id: id,
      in: context,
      node: node
    )
  }

  static func note(
    _ message: String,
    domain: String,
    id: String = "note",
    in context: some MacroExpansionContext,
    node: some SyntaxProtocol
  ) {
    diagnose(
      message: message,
      severity: .note,
      domain: domain,
      id: id,
      in: context,
      node: node
    )
  }

  private static func diagnose(
    message: String,
    severity: DiagnosticSeverity,
    domain: String,
    id: String,
    in context: some MacroExpansionContext,
    node: some SyntaxProtocol
  ) {
    let diagnosticMessage = MacroDiagnosticMessage(
      message: message,
      severity: severity,
      id: MessageID(domain: domain, id: id)
    )
    context.diagnose(Diagnostic(node: Syntax(node), message: diagnosticMessage))
  }
}

private struct MacroDiagnosticMessage: DiagnosticMessage {
  let message: String
  let severity: DiagnosticSeverity
  let id: MessageID

  var diagnosticID: MessageID { id }
}
