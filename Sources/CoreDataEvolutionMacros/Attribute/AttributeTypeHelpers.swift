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

func isAllowedDefaultAttributeType(_ type: TypeSyntax) -> Bool {
  guard let base = normalizedBaseTypeName(type) else {
    return false
  }
  return coreDataPrimitiveTypeNames.contains(base)
}

func attributeOptionalWrappedTypeName(_ type: TypeSyntax) -> String? {
  if let optional = type.as(OptionalTypeSyntax.self) {
    return optional.wrappedType.trimmedDescription
  }
  if let implicitly = type.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
    return implicitly.wrappedType.trimmedDescription
  }
  return nil
}

func numberBridgeAccessor(forBaseType typeName: String) -> String? {
  switch typeName {
  case "Int": return "intValue"
  case "Int16": return "int16Value"
  case "Int32": return "int32Value"
  case "Int64": return "int64Value"
  case "Float": return "floatValue"
  case "Double": return "doubleValue"
  case "Decimal": return "decimalValue"
  case "Bool": return "boolValue"
  default: return nil
  }
}
