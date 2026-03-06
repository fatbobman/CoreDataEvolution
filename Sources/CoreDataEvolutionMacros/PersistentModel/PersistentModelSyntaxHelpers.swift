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

import Foundation
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
  explicitObjCClassName(on: classDecl) != nil
}

func explicitObjCClassName(on classDecl: ClassDeclSyntax) -> String? {
  return classDecl.attributes
    .compactMap { $0.as(AttributeSyntax.self) }
    .compactMap { attribute -> String? in
      let name = attributeName(of: attribute)
      guard name == "objc" || name == "_objcRuntimeName" else {
        return nil
      }
      guard let arguments = attribute.arguments else {
        return nil
      }
      let text = arguments.trimmedDescription
      guard text != "()" && text.isEmpty == false else {
        return nil
      }
      return
        text
        .trimmingCharacters(in: CharacterSet(charactersIn: "()"))
        .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
    }
    .first
}

func optionalFallbackDefault(type: TypeSyntax) -> String? {
  if attributeOptionalWrappedTypeName(type) != nil {
    return "nil"
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
