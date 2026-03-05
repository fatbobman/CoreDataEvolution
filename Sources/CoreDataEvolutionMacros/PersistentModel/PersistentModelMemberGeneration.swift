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

func makeKeysDecl(
  accessModifier: String,
  model: PersistentModelAnalysis
) -> DeclSyntax {
  let attributes = model.attributes
  if attributes.isEmpty {
    return
      """
      \(raw: accessModifier)enum Keys: String {}
      """
  }
  let rows = attributes.map { attribute in
    "  case \(attribute.propertyName) = \"\(attribute.persistentName)\""
  }.joined(separator: "\n")
  return
    """
    \(raw: accessModifier)enum Keys: String {
    \(raw: rows)
    }
    """
}

func makePathsDecl(
  accessModifier: String,
  modelTypeName: String,
  model: PersistentModelAnalysis
) -> DeclSyntax {
  var lines: [String] = []

  for attribute in model.attributes {
    lines.append(
      """
      static let \(attribute.propertyName) = CoreDataEvolution.CDPath<\(modelTypeName), \(attribute.typeName)>(
        swiftPath: ["\(attribute.propertyName)"],
        persistentPath: ["\(attribute.persistentName)"],
        storageMethod: \(storageMethodExpression(attribute.storageMethod))
      )
      """
    )
  }

  for relation in model.relationships {
    switch relation.kind {
    case .toOne:
      lines.append(
        """
        static let \(relation.propertyName) = CoreDataEvolution.CDToOneRelationPath<\(modelTypeName), \(relation.targetTypeName)>(
          swiftPath: ["\(relation.propertyName)"],
          persistentPath: ["\(relation.propertyName)"]
        )
        """
      )
    case .toManySet, .toManyArray:
      lines.append(
        """
        static let \(relation.propertyName) = CoreDataEvolution.CDToManyRelationPath<\(modelTypeName), \(relation.targetTypeName)>(
          swiftPath: ["\(relation.propertyName)"],
          persistentPath: ["\(relation.propertyName)"]
        )
        """
      )
    }
  }

  let body = lines.joined(separator: "\n\n")
  return
    """
    \(raw: accessModifier)enum Paths {
    \(raw: body)
    }
    """
}

func makePathRootDecl(
  accessModifier: String,
  modelTypeName: String,
  model: PersistentModelAnalysis
) -> DeclSyntax {
  let props = model.attributes.map(\.propertyName) + model.relationships.map(\.propertyName)
  let impl = props.map { propertyName -> String in
    """
    var \(propertyName): \(pathTypeReference(for: propertyName, in: model, modelTypeName: modelTypeName)) {
      Paths.\(propertyName)
    }
    """
  }.joined(separator: "\n\n")

  if impl.isEmpty {
    return
      """
      \(raw: accessModifier)struct PathRoot: Sendable {}
      """
  }

  return
    """
    \(raw: accessModifier)struct PathRoot: Sendable {
    \(raw: impl)
    }
    """
}

private func pathTypeReference(
  for propertyName: String,
  in model: PersistentModelAnalysis,
  modelTypeName: String
) -> String {
  if let attribute = model.attributes.first(where: { $0.propertyName == propertyName }) {
    return "CoreDataEvolution.CDPath<\(modelTypeName), \(attribute.typeName)>"
  }
  if let relation = model.relationships.first(where: { $0.propertyName == propertyName }) {
    switch relation.kind {
    case .toOne:
      return "CoreDataEvolution.CDToOneRelationPath<\(modelTypeName), \(relation.targetTypeName)>"
    case .toManySet, .toManyArray:
      return "CoreDataEvolution.CDToManyRelationPath<\(modelTypeName), \(relation.targetTypeName)>"
    }
  }
  return "Never"
}

func makePathEntryDecl(accessModifier: String) -> DeclSyntax {
  """
  \(raw: accessModifier)static var path: PathRoot {
    .init()
  }
  """
}

func makeFieldTableDecl(
  accessModifier: String,
  modelTypeName: String,
  model: PersistentModelAnalysis
) -> DeclSyntax {
  var attributeRows: [String] = []
  for attribute in model.attributes {
    let supportsStoreSort = supportsStoreSort(attribute.storageMethod)
    let kind = attribute.storageMethod == .composition ? ".composition" : ".attribute"
    attributeRows.append(
      """
      "\(attribute.propertyName)": .init(
        kind: \(kind),
        swiftPath: ["\(attribute.propertyName)"],
        persistentPath: ["\(attribute.persistentName)"],
        storageMethod: \(storageMethodExpression(attribute.storageMethod)),
        supportsStoreSort: \(supportsStoreSort)
      )
      """
    )
  }
  let attributeLiteralBody = attributeRows.joined(separator: ",\n")

  var compositionMergeLines: [String] = []
  for attribute in model.attributes where attribute.storageMethod == .composition {
    let compositionType = unwrapOptionalTypeName(attribute.typeName)
    compositionMergeLines.append(
      """
      table.merge(
        CoreDataEvolution.CDCompositionTableBuilder.makeModelFieldEntries(
          modelSwiftPathPrefix: ["\(attribute.propertyName)"],
          modelPersistentPathPrefix: ["\(attribute.persistentName)"],
          composition: \(compositionType).self
        ),
        uniquingKeysWith: { _, new in new }
      )
      """
    )
  }
  let compositionMergeBlock = compositionMergeLines.joined(separator: "\n")

  var relationshipRows: [String] = []
  for relation in model.relationships {
    relationshipRows.append(
      """
      "\(relation.propertyName)": .init(
        kind: .relationship,
        swiftPath: ["\(relation.propertyName)"],
        persistentPath: ["\(relation.propertyName)"],
        storageMethod: .default,
        supportsStoreSort: false,
        isToManyRelationship: \(relation.kind == .toManySet || relation.kind == .toManyArray)
      )
      """
    )
  }
  let relationshipLiteralBody = relationshipRows.joined(separator: ",\n")

  var relationshipMergeLines: [String] = []
  for relation in model.relationships {
    switch relation.kind {
    case .toOne:
      relationshipMergeLines.append(
        """
        table.merge(
          CoreDataEvolution.CDRelationshipTableBuilder.makeToOneFieldEntries(
            modelSwiftPathPrefix: ["\(relation.propertyName)"],
            modelPersistentPathPrefix: ["\(relation.propertyName)"],
            target: \(relation.targetTypeName).self
          ),
          uniquingKeysWith: { _, new in new }
        )
        """
      )
    case .toManySet, .toManyArray:
      relationshipMergeLines.append(
        """
        table.merge(
          CoreDataEvolution.CDRelationshipTableBuilder.makeToManyFieldEntries(
            modelSwiftPathPrefix: ["\(relation.propertyName)"],
            modelPersistentPathPrefix: ["\(relation.propertyName)"],
            target: \(relation.targetTypeName).self
          ),
          uniquingKeysWith: { _, new in new }
        )
        """
      )
    }
  }
  let relationshipMergeBlock = relationshipMergeLines.joined(separator: "\n")
  return
    """
    \(raw: accessModifier)static let __cdRelationshipProjectionTable: [String: CoreDataEvolution.CDFieldMeta] = {
      var table: [String: CoreDataEvolution.CDFieldMeta] = [
      \(raw: attributeLiteralBody)
      ]
    \(raw: compositionMergeBlock)
      return table
    }()

    \(raw: accessModifier)static let __cdFieldTable: [String: CoreDataEvolution.CDFieldMeta] = {
      var table: [String: CoreDataEvolution.CDFieldMeta] = __cdRelationshipProjectionTable
      table.merge(
        [
      \(raw: relationshipLiteralBody)
        ],
        uniquingKeysWith: { _, new in new }
      )
    \(raw: relationshipMergeBlock)
      return table
    }()
    """
}

func makeInitDecl(
  accessModifier: String,
  properties: [PersistentModelInitProperty],
  generateInit: Bool
) -> DeclSyntax? {
  guard generateInit, properties.isEmpty == false else {
    return nil
  }

  let parameters = properties.map { property -> String in
    "\(property.propertyName): \(property.typeName)"
  }.joined(separator: ",\n")

  let assigns = properties.map {
    "self.\($0.propertyName) = \($0.propertyName)"
  }.joined(separator: "\n")

  return
    """
    \(raw: accessModifier)convenience init(
      \(raw: parameters)
    ) {
      self.init(entity: Self.entity(), insertInto: nil)
    \(raw: assigns)
    }
    """
}

func makeToManyHelpers(
  accessModifier: String,
  model: PersistentModelAnalysis,
  setterPolicy: ParsedRelationshipGenerationPolicy
) -> [DeclSyntax] {
  var result: [DeclSyntax] = []
  for relation in model.relationships {
    let key = relation.propertyName
    let type = relation.targetTypeName
    let suffix = uppercaseFirst(key)
    switch relation.kind {
    case .toOne:
      continue
    case .toManySet:
      result.append(
        """
        \(raw: accessModifier)func addTo\(raw: suffix)(_ value: \(raw: type)) {
          mutableSetValue(forKey: "\(raw: key)").add(value)
        }
        """
      )
      result.append(
        """
        \(raw: accessModifier)func removeFrom\(raw: suffix)(_ value: \(raw: type)) {
          mutableSetValue(forKey: "\(raw: key)").remove(value)
        }
        """
      )
      if setterPolicy != .none {
        let maybeDeprecated =
          setterPolicy == .warning
          ? "@available(*, deprecated, message: \"Bulk to-many setter may hide relationship mutation costs. Prefer add/remove helpers.\")\\n"
          : ""
        result.append(
          """
          \(raw: maybeDeprecated)\(raw: accessModifier)func replace\(raw: suffix)(with values: Set<\(raw: type)>) {
            setValue(NSSet(set: values), forKey: "\(raw: key)")
          }
          """
        )
      }
    case .toManyArray:
      result.append(
        """
        \(raw: accessModifier)func addTo\(raw: suffix)(_ value: \(raw: type)) {
          mutableOrderedSetValue(forKey: "\(raw: key)").add(value)
        }
        """
      )
      result.append(
        """
        \(raw: accessModifier)func removeFrom\(raw: suffix)(_ value: \(raw: type)) {
          mutableOrderedSetValue(forKey: "\(raw: key)").remove(value)
        }
        """
      )
    }
  }
  return result
}

private func storageMethodExpression(_ method: ParsedAttributeStorageMethod) -> String {
  switch method {
  case .default: return ".default"
  case .raw: return ".raw"
  case .codable: return ".codable"
  case .composition: return ".composition"
  case .transformed: return ".transformed"
  }
}

private func supportsStoreSort(_ method: ParsedAttributeStorageMethod) -> Bool {
  switch method {
  case .default, .raw:
    return true
  case .codable, .transformed, .composition:
    return false
  }
}

private func unwrapOptionalTypeName(_ typeName: String) -> String {
  let trimmed = trimWhitespace(typeName)
  if trimmed.hasSuffix("?") {
    return trimWhitespace(String(trimmed.dropLast()))
  }
  if trimmed.hasPrefix("Optional<"), trimmed.hasSuffix(">") {
    let start = trimmed.index(trimmed.startIndex, offsetBy: "Optional<".count)
    let end = trimmed.index(before: trimmed.endIndex)
    return trimWhitespace(String(trimmed[start..<end]))
  }
  return trimmed
}

private func trimWhitespace(_ text: String) -> String {
  text.trimmingCharacters(in: .whitespacesAndNewlines)
}
