//
//  ------------------------------------------------
//  Original project: CoreDataEvolution
//  Created on 2026/3/10 by Fatbobman(东坡肘子)
//  X: @fatbobman
//  Mastodon: @fatbobman@mastodon.social
//  GitHub: @fatbobman
//  Blog: https://fatbobman.com
//  ------------------------------------------------
//  Copyright © 2024-present Fatbobman. All rights reserved.

import SwiftSyntax
import SwiftSyntaxMacros

enum StoredPropertyValidationReason {
  case nonVariableDeclaration
  case notVar
  case staticOrClass
  case lazy
  case multipleBindings
  case computed
  case nonIdentifierPattern
  case missingTypeAnnotation
}

struct StoredPropertyValidationFailure: Error {
  let reason: StoredPropertyValidationReason
  let node: Syntax
}

struct StoredPropertyValidationMessages {
  let nonVariableDeclaration: String
  let notVar: String
  let staticOrClass: String
  let lazy: String
  let multipleBindings: String
  let computed: String
  let nonIdentifierPattern: String
  let missingTypeAnnotation: String
}

struct ValidatedStoredPropertyBinding {
  let binding: PatternBindingSyntax
  let identifierPattern: IdentifierPatternSyntax
  let typeAnnotation: TypeAnnotationSyntax
}

func validateStoredPropertyVariable(
  _ declaration: some DeclSyntaxProtocol
) -> Result<VariableDeclSyntax, StoredPropertyValidationFailure> {
  guard let variable = declaration.as(VariableDeclSyntax.self) else {
    return .failure(
      .init(
        reason: .nonVariableDeclaration,
        node: Syntax(declaration)
      )
    )
  }

  guard variable.bindingSpecifier.tokenKind == .keyword(.var) else {
    return .failure(
      .init(
        reason: .notVar,
        node: Syntax(variable)
      )
    )
  }

  if variable.modifiers.contains(where: { $0.name.text == "static" || $0.name.text == "class" }) {
    return .failure(
      .init(
        reason: .staticOrClass,
        node: Syntax(variable)
      )
    )
  }

  if variable.modifiers.contains(where: { $0.name.text == "lazy" }) {
    return .failure(
      .init(
        reason: .lazy,
        node: Syntax(variable)
      )
    )
  }

  return .success(variable)
}

func validateSingleStoredPropertyBinding(
  in variable: VariableDeclSyntax
) -> Result<ValidatedStoredPropertyBinding, StoredPropertyValidationFailure> {
  guard variable.bindings.count == 1, let binding = variable.bindings.first else {
    return .failure(
      .init(
        reason: .multipleBindings,
        node: Syntax(variable)
      )
    )
  }

  return validateStoredPropertyBinding(binding)
}

func validateStoredPropertyBinding(
  _ binding: PatternBindingSyntax
) -> Result<ValidatedStoredPropertyBinding, StoredPropertyValidationFailure> {
  if binding.accessorBlock != nil {
    return .failure(
      .init(
        reason: .computed,
        node: Syntax(binding)
      )
    )
  }

  guard let identifierPattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
    return .failure(
      .init(
        reason: .nonIdentifierPattern,
        node: Syntax(binding.pattern)
      )
    )
  }

  guard let typeAnnotation = binding.typeAnnotation else {
    return .failure(
      .init(
        reason: .missingTypeAnnotation,
        node: Syntax(binding.pattern)
      )
    )
  }

  return .success(
    .init(
      binding: binding,
      identifierPattern: identifierPattern,
      typeAnnotation: typeAnnotation
    )
  )
}

func emitStoredPropertyValidationFailure(
  _ failure: StoredPropertyValidationFailure,
  messages: StoredPropertyValidationMessages,
  domain: String,
  in context: some MacroExpansionContext
) {
  let message: String
  switch failure.reason {
  case .nonVariableDeclaration:
    message = messages.nonVariableDeclaration
  case .notVar:
    message = messages.notVar
  case .staticOrClass:
    message = messages.staticOrClass
  case .lazy:
    message = messages.lazy
  case .multipleBindings:
    message = messages.multipleBindings
  case .computed:
    message = messages.computed
  case .nonIdentifierPattern:
    message = messages.nonIdentifierPattern
  case .missingTypeAnnotation:
    message = messages.missingTypeAnnotation
  }

  MacroDiagnosticReporter.error(
    message,
    domain: domain,
    in: context,
    node: failure.node
  )
}
