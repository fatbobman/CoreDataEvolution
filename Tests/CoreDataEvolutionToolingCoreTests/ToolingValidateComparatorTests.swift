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

import CoreDataEvolutionToolingCore
import Foundation
import Testing

@Suite("Tooling Core Validate Comparator Tests")
struct ToolingValidateComparatorTests {
  @Test("comparator requires explicit relationship metadata for relationships")
  func comparatorRequiresExplicitRelationshipMetadataForRelationships() {
    let diagnostics = ToolingValidateComparator.compareQuick(
      expected: ambiguousRelationshipModelIR(),
      actual: .init(
        sourceDirectory: "/virtual/Sources",
        entities: [
          .init(
            filePath: "/virtual/Sources/Document.swift",
            className: "Document",
            objcEntityName: "Document",
            persistentModelArguments: .init(
              generateInit: false,
              relationshipSetterPolicy: .warning,
              relationshipCountPolicy: .none
            ),
            properties: [
              .init(
                filePath: "/virtual/Sources/Document.swift",
                name: "author",
                typeName: "User?",
                nonOptionalTypeName: "User",
                isOptional: true,
                defaultValueLiteral: "nil",
                isStored: true,
                isStatic: false,
                hasIgnore: false,
                attribute: nil,
                relationshipShape: .toOne
              ),
              .init(
                filePath: "/virtual/Sources/Document.swift",
                name: "editor",
                typeName: "User?",
                nonOptionalTypeName: "User",
                isOptional: true,
                defaultValueLiteral: "nil",
                isStored: true,
                isStatic: false,
                hasIgnore: false,
                attribute: nil,
                relationshipShape: .toOne
              ),
            ],
            customMembers: []
          )
        ]
      ),
      level: .conformance
    )

    #expect(
      diagnostics.contains {
        $0.message.contains(
          "requires explicit @Relationship(inverse:deleteRule:) for relationship 'Document.author'")
      })
    #expect(
      diagnostics.contains {
        $0.message.contains(
          "requires explicit @Relationship(inverse:deleteRule:) for relationship 'Document.editor'")
      })
  }

  @Test("comparator accepts matching relationship metadata")
  func comparatorAcceptsMatchingRelationshipMetadata() {
    let diagnostics = ToolingValidateComparator.compareQuick(
      expected: ambiguousRelationshipModelIR(),
      actual: .init(
        sourceDirectory: "/virtual/Sources",
        entities: [
          .init(
            filePath: "/virtual/Sources/Document.swift",
            className: "Document",
            objcEntityName: "Document",
            persistentModelArguments: .init(
              generateInit: false,
              relationshipSetterPolicy: .warning,
              relationshipCountPolicy: .none
            ),
            properties: [
              .init(
                filePath: "/virtual/Sources/Document.swift",
                name: "author",
                typeName: "User?",
                nonOptionalTypeName: "User",
                isOptional: true,
                defaultValueLiteral: "nil",
                isStored: true,
                isStatic: false,
                hasIgnore: false,
                attribute: nil,
                relationship: .init(
                  inversePropertyName: "authoredDocuments",
                  deleteRule: "nullify"
                ),
                relationshipShape: .toOne
              ),
              .init(
                filePath: "/virtual/Sources/Document.swift",
                name: "editor",
                typeName: "User?",
                nonOptionalTypeName: "User",
                isOptional: true,
                defaultValueLiteral: "nil",
                isStored: true,
                isStatic: false,
                hasIgnore: false,
                attribute: nil,
                relationship: .init(
                  inversePropertyName: "editedDocuments",
                  deleteRule: "nullify"
                ),
                relationshipShape: .toOne
              ),
            ],
            customMembers: []
          )
        ]
      ),
      level: .conformance
    )

    #expect(diagnostics.isEmpty)
  }
}

private func ambiguousRelationshipModelIR() -> ToolingModelIR {
  .init(
    source: .init(
      originalPath: "/virtual/AppModel.xcdatamodeld",
      selectedSourcePath: "/virtual/AppModel.xcdatamodeld/V1.xcdatamodel",
      compiledModelPath: "/virtual/AppModel.momd",
      inputKind: .xcdatamodeld,
      selectedVersionName: "V1.xcdatamodel"
    ),
    generationPolicy: .init(
      accessLevel: .internal,
      singleFile: false,
      splitByEntity: true,
      generateInit: false,
      relationshipSetterPolicy: .warning,
      relationshipCountPolicy: .none,
      defaultDecodeFailurePolicy: .fallbackToDefaultValue
    ),
    entities: [
      .init(
        name: "Document",
        managedObjectClassName: "NSManagedObject",
        representedClassName: "Document",
        attributes: [],
        relationships: [
          .init(
            persistentName: "author",
            swiftName: "author",
            destinationEntityName: "User",
            inverseRelationshipName: "authoredDocuments",
            cardinality: .toOne,
            isOptional: true,
            minCount: 0,
            maxCount: 1,
            deleteRule: "nullify"
          ),
          .init(
            persistentName: "editor",
            swiftName: "editor",
            destinationEntityName: "User",
            inverseRelationshipName: "editedDocuments",
            cardinality: .toOne,
            isOptional: true,
            minCount: 0,
            maxCount: 1,
            deleteRule: "nullify"
          ),
        ],
        compositions: []
      )
    ]
  )
}
