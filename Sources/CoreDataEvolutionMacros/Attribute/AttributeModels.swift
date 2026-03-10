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

let attributeMacroDomain = "CoreDataEvolution.AttributeMacro"

struct AttributeInfo {
  let propertyName: String
  let persistentName: String
  let typeName: String
  let nonOptionalTypeName: String
  let baseTypeName: String
  let isOptional: Bool
  let defaultValueExpression: String?
  let storageMethod: ParsedAttributeStorageMethod
  let decodeFailurePolicy: ParsedAttributeDecodeFailurePolicy?
  let isUnique: Bool
  let isTransient: Bool
}

enum ParsedAttributeStorageMethod: Equatable {
  case `default`
  case raw
  case codable
  case transformed(ParsedAttributeTransformedReference)
  case composition
}

enum ParsedAttributeTransformedReference: Equatable {
  case type(String)
  case name(String)
}

struct ParsedAttributeArguments {
  let traits: [ParsedAttributeTrait]
  let persistentName: String?
  let storageMethod: ParsedAttributeStorageMethod?
  let decodeFailurePolicy: ParsedAttributeDecodeFailurePolicy?
}

enum ParsedAttributeDecodeFailurePolicy: Equatable {
  case fallbackToDefaultValue
  case debugAssertNil
}

enum ParsedAttributeTrait: Equatable {
  case unique
  case transient
}
