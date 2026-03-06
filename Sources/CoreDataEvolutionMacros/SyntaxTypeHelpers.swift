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

import Foundation
import SwiftSyntax

/// Shared `TypeSyntax` helpers reused by PersistentModel, Attribute, Composition, and
/// Relationship macros.
///
/// Keep these helpers structural and domain-neutral so every macro reads the same optional,
/// collection, and normalized type-name rules.
func optionalWrappedTypeSyntax(_ type: TypeSyntax) -> TypeSyntax? {
  if let optional = type.as(OptionalTypeSyntax.self) {
    return optional.wrappedType
  }
  if let implicitly = type.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
    return implicitly.wrappedType
  }
  return nil
}

func optionalWrappedTypeName(_ type: TypeSyntax) -> String? {
  optionalWrappedTypeSyntax(type)?.trimmedDescription
}

func setElementTypeName(_ type: TypeSyntax) -> String? {
  guard let identifier = type.as(IdentifierTypeSyntax.self) else {
    return nil
  }
  guard identifier.name.text == "Set", let clause = identifier.genericArgumentClause else {
    return nil
  }
  guard clause.arguments.count == 1, let argument = clause.arguments.first else {
    return nil
  }
  return argument.argument.trimmedDescription
}

func arrayElementTypeName(_ type: TypeSyntax) -> String? {
  if let arrayType = type.as(ArrayTypeSyntax.self) {
    return arrayType.element.trimmedDescription
  }
  guard let identifier = type.as(IdentifierTypeSyntax.self) else {
    return nil
  }
  guard identifier.name.text == "Array", let clause = identifier.genericArgumentClause else {
    return nil
  }
  guard clause.arguments.count == 1, let argument = clause.arguments.first else {
    return nil
  }
  return argument.argument.trimmedDescription
}

/// Normalizes module-qualified primitive names to the plain form used throughout macro parsing.
func normalizedBaseTypeName(_ type: TypeSyntax) -> String? {
  if let wrapped = optionalWrappedTypeSyntax(type) {
    return normalizedBaseTypeName(wrapped)
  }

  let raw = type.trimmedDescription.replacingOccurrences(of: " ", with: "")
  if raw.hasPrefix("Swift.") {
    return String(raw.dropFirst("Swift.".count))
  }
  if raw.hasPrefix("Foundation.") {
    return String(raw.dropFirst("Foundation.".count))
  }
  return raw
}
