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

struct ParsedInverseDeclArguments: Equatable {
  let targetTypeName: String
  let inversePropertyName: String
}

func attributeName(of attribute: AttributeSyntax) -> String {
  attribute.attributeName.trimmedDescription
    .split(separator: ".")
    .last
    .map(String.init) ?? attribute.attributeName.trimmedDescription
}

func parseInverseDeclArguments(_ attribute: AttributeSyntax) -> ParsedInverseDeclArguments? {
  guard let list = attribute.arguments?.as(LabeledExprListSyntax.self),
    list.count == 2,
    let targetArgument = list.first,
    let propertyArgument = list.dropFirst().first
  else {
    return nil
  }

  let targetTypeText = targetArgument.expression.trimmedDescription
  guard targetTypeText.hasSuffix(".self") else {
    return nil
  }

  guard let propertyLiteral = propertyArgument.expression.as(StringLiteralExprSyntax.self),
    propertyLiteral.segments.count == 1,
    let segment = propertyLiteral.segments.first?.as(StringSegmentSyntax.self)
  else {
    return nil
  }

  let targetTypeName = String(targetTypeText.dropLast(".self".count))
  let inversePropertyName = segment.content.text
  guard targetTypeName.isEmpty == false, inversePropertyName.isEmpty == false else {
    return nil
  }
  return .init(
    targetTypeName: targetTypeName,
    inversePropertyName: inversePropertyName
  )
}

func typeNamesReferToSameEntity(_ lhs: String, _ rhs: String) -> Bool {
  if lhs == rhs {
    return true
  }
  return lhs.split(separator: ".").last == rhs.split(separator: ".").last
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
