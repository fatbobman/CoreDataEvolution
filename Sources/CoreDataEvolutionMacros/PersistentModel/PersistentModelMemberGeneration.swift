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

struct PersistentModelPathEntry: Equatable {
  enum Kind: Equatable {
    case attribute
    case composition
    case toOneRelationship
    case toManyRelationship
  }

  let propertyName: String
  let kind: Kind
  let typeReference: String
  let declaration: String
}

struct PersistentModelFieldTableRendering: Equatable {
  let relationshipProjectionTableDecl: String
  let fieldTableDecl: String
}

private struct PersistentModelObservationFieldEntry: Equatable {
  let propertyName: String
  // nil means the getter has an observable field ID, but save-hook changedValues() has no key.
  let coreDataKey: String?
}

func makeKeysDecl(
  accessModifier: String,
  model: PersistentModelAnalysis
) -> DeclSyntax {
  let attributes = model.attributes
  if attributes.isEmpty {
    return
      """
      \(raw: accessModifier)enum Keys: RawRepresentable {
        \(raw: accessModifier)typealias RawValue = String

        \(raw: accessModifier)init?(rawValue: String) {
          return nil
        }

        \(raw: accessModifier)var rawValue: String {
          switch self {}
        }
      }
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
  let body = collectPersistentModelPathEntries(
    accessModifier: accessModifier,
    modelTypeName: modelTypeName,
    model: model
  )
  .map(\.declaration)
  .joined(separator: "\n\n")
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
    \(accessModifier)var \(propertyName): \(pathTypeReference(for: propertyName, in: model, modelTypeName: modelTypeName)) {
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
    if attribute.storageMethod == .composition {
      return
        "CoreDataEvolution.CDCompositionPath<\(modelTypeName), \(attribute.typeName), \(attribute.nonOptionalTypeName)>"
    }
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

func makeObservationRegistrarDecls(modelTypeName: String) -> [DeclSyntax] {
  [
    """
    \(raw: cdeObservationAvailability)
    private let _$observationRegistrar = CoreDataEvolution.CDEObservationRegistrar()
    """
  ]
}

func makeObservationFieldMapDecls(
  accessModifier: String,
  modelTypeName: String,
  model: PersistentModelAnalysis,
  generateToManyCount: Bool
) -> [DeclSyntax] {
  let fields = collectObservationFieldEntries(
    model: model,
    generateToManyCount: generateToManyCount
  )
  let mapRows = collectObservationCoreDataKeyRows(fields: fields)
    .map { coreDataKey, fields -> String in
      let rawValues =
        fields
        .map { "__CDObservationFieldID.\($0.propertyName).rawValue" }
        .joined(separator: ", ")
      return
        #""\#(escapeStringLiteral(coreDataKey))": .init(rawValues: [\#(rawValues)])"#
    }
    .joined(separator: ",\n")
  let mapLiteral = mapRows.isEmpty ? "[:]" : "[\n\(mapRows)\n    ]"

  var declarations: [DeclSyntax] = []
  if fields.isEmpty == false {
    declarations.append(
      "\(raw: makeObservationFieldIDDecl(modelTypeName: modelTypeName, fields: fields))"
    )
  }

  declarations.append(
    """
    \(raw: cdeObservationAvailability)
    \(raw: accessModifier)static let __cdObservationFieldMap = CoreDataEvolution.CDEObservationFieldMap(
      fieldsByCoreDataKey: \(raw: mapLiteral)
    )
    """
  )
  declarations.append(
    """
    \(raw: cdeObservationAvailability)
    \(raw: accessModifier)static func __cdObservationFieldSet<CoreDataKeys>(
      forCoreDataKeys coreDataKeys: CoreDataKeys
    ) -> CoreDataEvolution.CDEObservationFieldSet where CoreDataKeys: Sequence, CoreDataKeys.Element == String {
      __cdObservationFieldMap.fieldSet(forCoreDataKeys: coreDataKeys)
    }
    """
  )
  declarations.append(
    """
    \(raw: cdeObservationAvailability)
    \(raw: accessModifier)static func __cdObservationSwiftPaths(
      for fieldSet: CoreDataEvolution.CDEObservationFieldSet
    ) -> [String] {
      \(raw: makeObservationFieldEnumerationBody(fields: fields, member: "swiftPath"))
    }
    """
  )
  declarations.append(
    """
    \(raw: cdeObservationAvailability)
    \(raw: accessModifier)static func __cdObservationKeyPaths(
      for fieldSet: CoreDataEvolution.CDEObservationFieldSet
    ) -> [PartialKeyPath<\(raw: modelTypeName)>] {
      \(raw: makeObservationFieldEnumerationBody(fields: fields, member: "keyPath"))
    }
    """
  )
  declarations += makeObservationInvalidationDispatchDecls(
    accessModifier: accessModifier,
    fields: fields
  )
  return declarations
}

func makeFieldTableDecls(
  accessModifier: String,
  modelTypeName: String,
  model: PersistentModelAnalysis
) -> [DeclSyntax] {
  let rendering = collectPersistentModelFieldTableRendering(
    accessModifier: accessModifier,
    model: model
  )
  return [
    "\(raw: rendering.relationshipProjectionTableDecl)",
    "\(raw: rendering.fieldTableDecl)",
  ]
}

private func collectObservationFieldEntries(
  model: PersistentModelAnalysis,
  generateToManyCount: Bool
) -> [PersistentModelObservationFieldEntry] {
  var entries: [PersistentModelObservationFieldEntry] = []

  for property in model.properties {
    switch property {
    case .attribute(let attribute):
      guard attribute.isObservationTracked else { continue }
      entries.append(
        .init(
          propertyName: attribute.propertyName,
          coreDataKey: attribute.isTransient ? nil : attribute.persistentName
        )
      )
    case .relationship(let relationship):
      guard relationship.isObservationTracked else { continue }
      entries.append(
        .init(
          propertyName: relationship.propertyName,
          coreDataKey: relationship.persistentName
        )
      )
      guard generateToManyCount,
        relationship.kind == .toManySet || relationship.kind == .toManyArray
      else {
        continue
      }
      entries.append(
        .init(
          propertyName: toManyCountPropertyName(for: relationship.propertyName),
          coreDataKey: relationship.persistentName
        )
      )
    }
  }

  return entries
}

private func collectObservationCoreDataKeyRows(
  fields: [PersistentModelObservationFieldEntry]
) -> [(String, [PersistentModelObservationFieldEntry])] {
  var rows: [(String, [PersistentModelObservationFieldEntry])] = []
  for field in fields {
    guard let coreDataKey = field.coreDataKey else { continue }
    if let index = rows.firstIndex(where: { $0.0 == coreDataKey }) {
      rows[index].1.append(field)
    } else {
      rows.append((coreDataKey, [field]))
    }
  }
  return rows
}

private func makeObservationFieldIDDecl(
  modelTypeName: String,
  fields: [PersistentModelObservationFieldEntry]
) -> String {
  let cases = fields.enumerated()
    .map { index, field in
      "  case \(field.propertyName) = \(index)"
    }
    .joined(separator: "\n")
  let swiftPathCases =
    fields
    .map { field in
      #"    case .\#(field.propertyName): return "\#(escapeStringLiteral(field.propertyName))""#
    }
    .joined(separator: "\n")
  let keyPathCases =
    fields
    .map { field in
      "    case .\(field.propertyName): return \\\(modelTypeName).\(field.propertyName)"
    }
    .joined(separator: "\n")

  return
    """
    \(cdeObservationAvailability)
    private enum __CDObservationFieldID: UInt16, CaseIterable {
    \(cases)

      var swiftPath: String {
        switch self {
    \(swiftPathCases)
        }
      }

      var keyPath: PartialKeyPath<\(modelTypeName)> {
        switch self {
    \(keyPathCases)
        }
      }
    }
    """
}

private func makeObservationFieldEnumerationBody(
  fields: [PersistentModelObservationFieldEntry],
  member: String
) -> String {
  guard fields.isEmpty == false else {
    return "[]"
  }
  return
    """
    __CDObservationFieldID.allCases.compactMap { field in
      fieldSet.contains(rawValue: field.rawValue) ? field.\(member) : nil
    }
    """
}

private func makeObservationInvalidationDispatchDecls(
  accessModifier: String,
  fields: [PersistentModelObservationFieldEntry]
) -> [DeclSyntax] {
  guard fields.isEmpty == false else {
    return [
      """
      \(raw: cdeObservationAvailability)
      \(raw: accessModifier)func __cdObservationInvalidate(
        fieldSet: CoreDataEvolution.CDEObservationFieldSet
      ) {}
      """,
      """
      \(raw: cdeObservationAvailability)
      \(raw: accessModifier)func __cdObservationInvalidateAllObservableKeyPaths() {}
      """,
    ]
  }

  let cases =
    fields
    .map { field in
      """
          case .\(field.propertyName):
            _$observationRegistrar.withMutation(of: self, keyPath: \\.\(field.propertyName)) {}
      """
    }
    .joined(separator: "\n")

  return [
    """
    \(raw: cdeObservationAvailability)
    \(raw: accessModifier)func __cdObservationInvalidate(
      fieldSet: CoreDataEvolution.CDEObservationFieldSet
    ) {
      for field in __CDObservationFieldID.allCases {
        guard fieldSet.contains(rawValue: field.rawValue) else {
          continue
        }
        __cdObservationInvalidate(field)
      }
    }
    """,
    """
    \(raw: cdeObservationAvailability)
    \(raw: accessModifier)func __cdObservationInvalidateAllObservableKeyPaths() {
      for field in __CDObservationFieldID.allCases {
        __cdObservationInvalidate(field)
      }
    }
    """,
    """
    \(raw: cdeObservationAvailability)
    private func __cdObservationInvalidate(_ field: __CDObservationFieldID) {
      switch field {
    \(raw: cases)
      }
    }
    """,
  ]
}

func collectPersistentModelPathEntries(
  accessModifier: String,
  modelTypeName: String,
  model: PersistentModelAnalysis
) -> [PersistentModelPathEntry] {
  var entries: [PersistentModelPathEntry] = []

  for attribute in model.attributes {
    if attribute.storageMethod == .composition {
      entries.append(
        .init(
          propertyName: attribute.propertyName,
          kind: .composition,
          typeReference:
            "CoreDataEvolution.CDCompositionPath<\(modelTypeName), \(attribute.typeName), \(attribute.nonOptionalTypeName)>",
          declaration:
            """
            \(accessModifier)static let \(attribute.propertyName) = CoreDataEvolution.CDCompositionPath<\(modelTypeName), \(attribute.typeName), \(attribute.nonOptionalTypeName)>(
              root: CoreDataEvolution.CDPath<\(modelTypeName), \(attribute.typeName)>(
                swiftPath: ["\(attribute.propertyName)"],
                persistentPath: ["\(attribute.persistentName)"],
                storageMethod: .composition
              )
            )
            """
        )
      )
    } else {
      entries.append(
        .init(
          propertyName: attribute.propertyName,
          kind: .attribute,
          typeReference: "CoreDataEvolution.CDPath<\(modelTypeName), \(attribute.typeName)>",
          declaration:
            """
            \(accessModifier)static let \(attribute.propertyName) = CoreDataEvolution.CDPath<\(modelTypeName), \(attribute.typeName)>(
              swiftPath: ["\(attribute.propertyName)"],
              persistentPath: ["\(attribute.persistentName)"],
              storageMethod: \(storageMethodExpression(attribute.storageMethod))
            )
            """
        )
      )
    }
  }

  for relation in model.relationships {
    switch relation.kind {
    case .toOne:
      entries.append(
        .init(
          propertyName: relation.propertyName,
          kind: .toOneRelationship,
          typeReference:
            "CoreDataEvolution.CDToOneRelationPath<\(modelTypeName), \(relation.targetTypeName)>",
          declaration:
            """
            \(accessModifier)static let \(relation.propertyName) = CoreDataEvolution.CDToOneRelationPath<\(modelTypeName), \(relation.targetTypeName)>(
              swiftPath: ["\(relation.propertyName)"],
              persistentPath: ["\(relation.persistentName)"]
            )
            """
        )
      )
    case .toManySet, .toManyArray:
      entries.append(
        .init(
          propertyName: relation.propertyName,
          kind: .toManyRelationship,
          typeReference:
            "CoreDataEvolution.CDToManyRelationPath<\(modelTypeName), \(relation.targetTypeName)>",
          declaration:
            """
            \(accessModifier)static let \(relation.propertyName) = CoreDataEvolution.CDToManyRelationPath<\(modelTypeName), \(relation.targetTypeName)>(
              swiftPath: ["\(relation.propertyName)"],
              persistentPath: ["\(relation.persistentName)"]
            )
            """
        )
      )
    }
  }

  return entries
}

func collectPersistentModelFieldTableRendering(
  accessModifier: String,
  model: PersistentModelAnalysis
) -> PersistentModelFieldTableRendering {
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
  let attributeTableLiteral =
    attributeLiteralBody.isEmpty ? "[:]" : "[\n\(attributeLiteralBody)\n    ]"

  var compositionMergeLines: [String] = []
  for attribute in model.attributes where attribute.storageMethod == .composition {
    let compositionType = attribute.nonOptionalTypeName
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
        persistentPath: ["\(relation.persistentName)"],
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
            modelPersistentPathPrefix: ["\(relation.persistentName)"],
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
            modelPersistentPathPrefix: ["\(relation.persistentName)"],
            target: \(relation.targetTypeName).self
          ),
          uniquingKeysWith: { _, new in new }
        )
        """
      )
    }
  }
  let relationshipMergeBlock = relationshipMergeLines.joined(separator: "\n")
  return .init(
    relationshipProjectionTableDecl:
      """
      \(accessModifier)static let __cdRelationshipProjectionTable: [String: CoreDataEvolution.CDFieldMeta] = {
        var table: [String: CoreDataEvolution.CDFieldMeta] = \(attributeTableLiteral)
      \(compositionMergeBlock)
        return table
      }()
      """,
    fieldTableDecl:
      """
      \(accessModifier)static let __cdFieldTable: [String: CoreDataEvolution.CDFieldMeta] = {
        var table: [String: CoreDataEvolution.CDFieldMeta] = __cdRelationshipProjectionTable
        table.merge(
          [
        \(relationshipLiteralBody)
          ],
          uniquingKeysWith: { _, new in new }
        )
      \(relationshipMergeBlock)
        return table
      }()
      """
  )
}

func makeRelationshipTargetValidationDecls(
  accessModifier: String,
  model: PersistentModelAnalysis
) -> [DeclSyntax] {
  model.relationships.map { relationship in
    return
      """
      \(raw: accessModifier)static let __cd_relationship_validate_\(raw: relationship.propertyName)_entity: Void = CoreDataEvolution._CDRelationshipMacroValidation.requirePersistentEntity(\(raw: relationship.targetTypeName).self)
      """
  }
}

func makeRuntimeEntitySchemaDecl(
  accessModifier: String,
  modelTypeName: String,
  objcClassName: String,
  model: PersistentModelAnalysis
) -> DeclSyntax {
  let attributeRows = model.attributes.map { attribute in
    let transientArgument = attribute.isTransient ? ",\n      isTransient: true" : ""
    return """
      CoreDataEvolution.CDRuntimeAttributeSchema(
        swiftName: "\(attribute.propertyName)",
        persistentName: "\(attribute.persistentName)",
        swiftTypeName: "\(attribute.typeName)",
        isOptional: \(attribute.isOptional),
        defaultValueExpression: \(runtimeDefaultValueExpression(attribute.defaultValueExpression)),
        storage: \(runtimeStorageExpression(attribute)),
        isUnique: \(attribute.isUnique)\(transientArgument)
      )
      """
  }.joined(separator: ",\n")

  let relationshipRows = model.relationships.compactMap { relationship -> String? in
    guard let inverseName = relationship.inverseName,
      let deleteRule = relationship.deleteRule
    else {
      // Relationship metadata is validated earlier. Keep runtime schema emission defensive so
      // partially-invalid analysis does not crash member generation.
      return nil
    }
    let minimumModelCountArgument =
      relationship.minimumModelCount.map {
        ",\n        minimumModelCount: \($0)"
      } ?? ""
    let maximumModelCountArgument =
      relationship.maximumModelCount.map {
        ",\n        maximumModelCount: \($0)"
      } ?? ""
    let deleteRuleLine =
      "deleteRule: \(runtimeRelationshipDeleteRuleExpression(deleteRule))\(minimumModelCountArgument)\(maximumModelCountArgument)"
    return """
      CoreDataEvolution.CDRuntimeRelationshipSchema(
        swiftName: "\(relationship.propertyName)",
        persistentName: "\(relationship.persistentName)",
        targetTypeName: "\(relationship.targetTypeName)",
        inverseName: "\(inverseName)",
        \(deleteRuleLine),
        kind: \(runtimeRelationshipKindExpression(relationship.kind)),
        isOptional: true
      )
      """
  }.joined(separator: ",\n")

  let uniquenessRows = model.attributes
    .filter(\.isUnique)
    .map { attribute in
      """
      CoreDataEvolution.CDRuntimeUniquenessConstraint(
        persistentPropertyNames: ["\(attribute.persistentName)"]
      )
      """
    }
    .joined(separator: ",\n")

  return
    """
    \(raw: accessModifier)static var __cdRuntimeEntitySchema: CoreDataEvolution.CDRuntimeEntitySchema {
      .init(
        entityName: "\(raw: objcClassName)",
        managedObjectClassName: NSStringFromClass(Self.self),
        attributes: [
          \(raw: attributeRows)
        ],
        relationships: [
          \(raw: relationshipRows)
        ],
        uniquenessConstraints: [
          \(raw: uniquenessRows)
        ]
      )
    }
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

func makeFetchRequestDecl(
  accessModifier: String,
  modelTypeName: String,
  objcClassName: String
) -> DeclSyntax {
  """
  @nonobjc
  \(raw: accessModifier)class func fetchRequest() -> NSFetchRequest<\(raw: modelTypeName)> {
    NSFetchRequest<\(raw: modelTypeName)>(entityName: "\(raw: objcClassName)")
  }
  """
}

func makeToManyHelpers(
  accessModifier: String,
  model: PersistentModelAnalysis
) -> [DeclSyntax] {
  var result: [DeclSyntax] = []
  for relation in model.relationships {
    let key = relation.persistentName
    let type = relation.targetTypeName
    let suffix = uppercaseFirst(relation.propertyName)
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
      result.append(
        """
        \(raw: accessModifier)func addTo\(raw: suffix)(_ values: Set<\(raw: type)>) {
          let mutable = mutableSetValue(forKey: "\(raw: key)")
          for value in values {
            mutable.add(value)
          }
        }
        """
      )
      result.append(
        """
        \(raw: accessModifier)func removeFrom\(raw: suffix)(_ values: Set<\(raw: type)>) {
          let mutable = mutableSetValue(forKey: "\(raw: key)")
          for value in values {
            mutable.remove(value)
          }
        }
        """
      )
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
      result.append(
        """
        \(raw: accessModifier)func addTo\(raw: suffix)(_ values: [\(raw: type)]) {
          let mutable = mutableOrderedSetValue(forKey: "\(raw: key)")
          for value in values {
            mutable.add(value)
          }
        }
        """
      )
      result.append(
        """
        \(raw: accessModifier)func removeFrom\(raw: suffix)(_ values: [\(raw: type)]) {
          let mutable = mutableOrderedSetValue(forKey: "\(raw: key)")
          for value in values {
            mutable.remove(value)
          }
        }
        """
      )
      result.append(
        """
        \(raw: accessModifier)func insertInto\(raw: suffix)(_ value: \(raw: type), at index: Int) {
          mutableOrderedSetValue(forKey: "\(raw: key)").insert(value, at: index)
        }
        """
      )
    }
  }
  return result
}

func makeToManyCountDecls(
  accessModifier: String,
  model: PersistentModelAnalysis,
  generateToManyCount: Bool,
  observation: ParsedPersistentModelObservationMode
) -> [DeclSyntax] {
  guard generateToManyCount else { return [] }

  var result: [DeclSyntax] = []
  for relation in model.relationships {
    let key = relation.persistentName
    let propertyName = toManyCountPropertyName(for: relation.propertyName)
    let getterObservation: ParsedPersistentModelObservationMode =
      relation.isObservationTracked ? observation : .none
    switch relation.kind {
    case .toOne:
      continue
    case .toManySet:
      if getterObservation == .mainActor {
        let getter = makeObservationTrackedGetter(
          """
          get {
            return (value(forKey: "\(raw: key)") as? NSSet)?.count ?? 0
          }
          """,
          propertyName: propertyName,
          observation: getterObservation
        )
        result.append(
          """
          \(raw: accessModifier)var \(raw: propertyName): Int {
            \(raw: getter.description)
          }
          """
        )
      } else {
        result.append(
          """
          \(raw: accessModifier)var \(raw: propertyName): Int {
            (value(forKey: "\(raw: key)") as? NSSet)?.count ?? 0
          }
          """
        )
      }
    case .toManyArray:
      if getterObservation == .mainActor {
        let getter = makeObservationTrackedGetter(
          """
          get {
            return (value(forKey: "\(raw: key)") as? NSOrderedSet)?.count ?? 0
          }
          """,
          propertyName: propertyName,
          observation: getterObservation
        )
        result.append(
          """
          \(raw: accessModifier)var \(raw: propertyName): Int {
            \(raw: getter.description)
          }
          """
        )
      } else {
        result.append(
          """
          \(raw: accessModifier)var \(raw: propertyName): Int {
            (value(forKey: "\(raw: key)") as? NSOrderedSet)?.count ?? 0
          }
          """
        )
      }
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

private func runtimeStorageExpression(_ attribute: PersistentAttributeProperty) -> String {
  switch attribute.storageMethod {
  case .default:
    return
      ".primitive(\(runtimePrimitiveTypeExpression(typeName: attribute.nonOptionalTypeName)))"
  case .raw:
    return
      ".raw(backingTypeName: String(describing: \(attribute.nonOptionalTypeName).RawValue.self))"
  case .codable:
    return ".codable"
  case .transformed(let transformer):
    switch transformer {
    case .type(let transformerType):
      return ".transformed(transformerName: \(transformerType).transformerName.rawValue)"
    case .name(let transformerName):
      return #".transformed(transformerName: "\#(escapeStringLiteral(transformerName))")"#
    }
  case .composition:
    return ".composition(fields: \(attribute.nonOptionalTypeName).__cdRuntimeCompositionFields)"
  }
}

private func runtimeRelationshipKindExpression(_ kind: PersistentRelationshipProperty.Kind)
  -> String
{
  switch kind {
  case .toOne:
    return ".toOne"
  case .toManySet:
    return ".toManySet"
  case .toManyArray:
    return ".toManyArray"
  }
}

private func runtimeRelationshipDeleteRuleExpression(_ rule: ParsedRelationshipDeleteRule) -> String
{
  switch rule {
  case .nullify:
    return ".nullify"
  case .cascade:
    return ".cascade"
  case .deny:
    return ".deny"
  }
}
