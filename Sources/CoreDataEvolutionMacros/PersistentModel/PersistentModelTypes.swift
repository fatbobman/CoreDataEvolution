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

let persistentModelMacroDomain = "CoreDataEvolution.PersistentModelMacro"

struct PersistentModelArguments {
  let generateInit: Bool
  let relationshipSetterPolicy: ParsedRelationshipGenerationPolicy
  let relationshipCountPolicy: ParsedRelationshipGenerationPolicy
}

enum ParsedRelationshipGenerationPolicy: String {
  case none
  case warning
  case plain
}

enum PersistentModelPropertyKind {
  case attribute(PersistentAttributeProperty)
  case relationship(PersistentRelationshipProperty)
}

struct PersistentModelAnalysis {
  let properties: [PersistentModelPropertyKind]

  var attributes: [PersistentAttributeProperty] {
    properties.compactMap {
      if case .attribute(let value) = $0 { return value }
      return nil
    }
  }

  var relationships: [PersistentRelationshipProperty] {
    properties.compactMap {
      if case .relationship(let value) = $0 { return value }
      return nil
    }
  }
}

struct PersistentAttributeProperty {
  let propertyName: String
  let typeName: String
  let nonOptionalTypeName: String
  let persistentName: String
  let isOptional: Bool
  let storageMethod: ParsedAttributeStorageMethod
  let defaultValueExpression: String?
  let isUnique: Bool
  let isTransient: Bool
}

struct PersistentRelationshipProperty {
  enum Kind {
    case toOne
    case toManySet
    case toManyArray
  }

  let propertyName: String
  let targetTypeName: String
  let kind: Kind
}

struct PersistentModelInitProperty {
  let propertyName: String
  let typeName: String
}
