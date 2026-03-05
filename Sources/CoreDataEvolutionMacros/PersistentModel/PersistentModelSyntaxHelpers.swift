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

func firstAttribute(named name: String, in variable: VariableDeclSyntax) -> AttributeSyntax? {
  variable.attributes
    .compactMap { $0.as(AttributeSyntax.self) }
    .first { attributeName(of: $0) == name }
}

func hasMarkerAttribute(_ name: String, in variable: VariableDeclSyntax) -> Bool {
  firstAttribute(named: name, in: variable) != nil
}

func attributeName(of attribute: AttributeSyntax) -> String {
  attribute.attributeName.trimmedDescription
    .split(separator: ".")
    .last
    .map(String.init) ?? attribute.attributeName.trimmedDescription
}

func hasExplicitObjCClassName(on classDecl: ClassDeclSyntax) -> Bool {
  classDecl.attributes
    .compactMap { $0.as(AttributeSyntax.self) }
    .contains { attribute in
      let name = attributeName(of: attribute)
      guard name == "objc" || name == "_objcRuntimeName" else {
        return false
      }
      guard let arguments = attribute.arguments else {
        return false
      }
      let text = arguments.trimmedDescription
      return text != "()" && text.isEmpty == false
    }
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

func optionalFallbackDefault(type: TypeSyntax) -> String? {
  if attributeOptionalWrappedTypeName(type) != nil {
    return "nil"
  }
  return nil
}

func optionalWrappedTypeSyntax(_ type: TypeSyntax) -> TypeSyntax? {
  if let optional = type.as(OptionalTypeSyntax.self) {
    return optional.wrappedType
  }
  if let implicitly = type.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
    return implicitly.wrappedType
  }
  return nil
}

func uppercaseFirst(_ text: String) -> String {
  guard let first = text.first else { return text }
  return String(first).uppercased() + text.dropFirst()
}

extension ClassDeclSyntax {
  var inheritsFromNSManagedObject: Bool {
    guard let inheritanceClause else {
      return false
    }
    for inherited in inheritanceClause.inheritedTypes {
      let text = inherited.type.trimmedDescription
      if text == "NSManagedObject" || text == "CoreData.NSManagedObject" {
        return true
      }
    }
    return false
  }
}
