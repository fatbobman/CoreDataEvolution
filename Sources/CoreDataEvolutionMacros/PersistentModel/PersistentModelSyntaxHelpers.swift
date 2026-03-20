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

func preferredAttributeForParsing(named name: String, in variable: VariableDeclSyntax)
  -> AttributeSyntax?
{
  let attributes = variable.attributes.compactMap { $0.as(AttributeSyntax.self) }
    .filter { attributeName(of: $0) == name }
  return attributes.first(where: { $0.arguments != nil }) ?? attributes.first
}

struct ParsedRelationshipDeclArguments: Equatable {
  let persistentName: String?
  let inversePropertyName: String
  let deleteRule: ParsedRelationshipDeleteRule
  let minimumModelCount: Int?
  let maximumModelCount: Int?
}

enum ParsedRelationshipDeleteRule: String, Equatable {
  case nullify
  case cascade
  case deny
}

enum RelationshipDeclArgumentsParseError: Error, Equatable {
  case missingInverseArgument
  case invalidInverseArgument
  case missingDeleteRuleArgument
  case invalidDeleteRuleArgument
  case unsupportedDeleteRuleArgument
  case invalidMinimumModelCountArgument
  case invalidMaximumModelCountArgument
  case invalidShape
}

func attributeName(of attribute: AttributeSyntax) -> String {
  attribute.attributeName.trimmedDescription
    .split(separator: ".")
    .last
    .map(String.init) ?? attribute.attributeName.trimmedDescription
}

func parseRelationshipDeclArguments(
  _ attribute: AttributeSyntax
) -> Result<ParsedRelationshipDeclArguments, RelationshipDeclArgumentsParseError> {
  guard let list = attribute.arguments?.as(LabeledExprListSyntax.self) else {
    return .failure(.invalidShape)
  }

  var inversePropertyName: String?
  var deleteRule: ParsedRelationshipDeleteRule?
  var minimumModelCount: Int?
  var maximumModelCount: Int?
  var persistentName: String?

  for argument in list {
    guard let label = argument.label?.text else {
      return .failure(.invalidShape)
    }

    switch label {
    case "persistentName":
      if argument.expression.trimmedDescription == "nil" {
        persistentName = nil
        continue
      }
      guard let propertyLiteral = argument.expression.as(StringLiteralExprSyntax.self),
        propertyLiteral.segments.count == 1,
        let segment = propertyLiteral.segments.first?.as(StringSegmentSyntax.self)
      else {
        return .failure(.invalidShape)
      }
      let value = segment.content.text
      guard value.isEmpty == false else {
        return .failure(.invalidShape)
      }
      persistentName = value
    case "inverse":
      guard let propertyLiteral = argument.expression.as(StringLiteralExprSyntax.self),
        propertyLiteral.segments.count == 1,
        let segment = propertyLiteral.segments.first?.as(StringSegmentSyntax.self)
      else {
        return .failure(.invalidInverseArgument)
      }
      let value = segment.content.text
      guard value.isEmpty == false else {
        return .failure(.invalidInverseArgument)
      }
      inversePropertyName = value
    case "deleteRule":
      let raw = argument.expression.trimmedDescription.replacingOccurrences(of: " ", with: "")
      if raw == ".noAction"
        || raw == "RelationshipDeleteRule.noAction"
        || raw == "CoreDataEvolution.RelationshipDeleteRule.noAction"
      {
        return .failure(.unsupportedDeleteRuleArgument)
      }
      deleteRule = parseRelationshipDeleteRule(from: raw)
      if deleteRule == nil {
        return .failure(.invalidDeleteRuleArgument)
      }
    case "minimumModelCount":
      guard let value = parseRelationshipCountLiteral(from: argument.expression) else {
        return .failure(.invalidMinimumModelCountArgument)
      }
      minimumModelCount = value
    case "maximumModelCount":
      guard let value = parseRelationshipCountLiteral(from: argument.expression) else {
        return .failure(.invalidMaximumModelCountArgument)
      }
      maximumModelCount = value
    default:
      return .failure(.invalidShape)
    }
  }

  guard let inversePropertyName else {
    return .failure(.missingInverseArgument)
  }
  guard let deleteRule else {
    return .failure(.missingDeleteRuleArgument)
  }

  return .success(
    .init(
      persistentName: persistentName,
      inversePropertyName: inversePropertyName,
      deleteRule: deleteRule,
      minimumModelCount: minimumModelCount,
      maximumModelCount: maximumModelCount
    )
  )
}

private func parseRelationshipCountLiteral(from expression: ExprSyntax) -> Int? {
  guard let literal = expression.as(IntegerLiteralExprSyntax.self) else {
    return nil
  }
  guard let value = Int(literal.literal.text), value >= 0 else {
    return nil
  }
  return value
}

func parseRelationshipDeleteRule(from raw: String) -> ParsedRelationshipDeleteRule? {
  switch raw {
  case ".nullify", "RelationshipDeleteRule.nullify",
    "CoreDataEvolution.RelationshipDeleteRule.nullify":
    return .nullify
  case ".cascade", "RelationshipDeleteRule.cascade",
    "CoreDataEvolution.RelationshipDeleteRule.cascade":
    return .cascade
  case ".deny", "RelationshipDeleteRule.deny", "CoreDataEvolution.RelationshipDeleteRule.deny":
    return .deny
  default:
    return nil
  }
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

func toManyCountPropertyName(for propertyName: String) -> String {
  "\(propertyName)Count"
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
