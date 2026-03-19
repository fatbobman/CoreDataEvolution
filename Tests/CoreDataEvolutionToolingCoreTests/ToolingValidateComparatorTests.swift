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
            ),
            properties: [
              .init(
                filePath: "/virtual/Sources/Document.swift",
                name: "author",
                typeName: "User?",
                nonOptionalTypeName: "User",
                declarationRange: dummyRange(0, 0),
                declarationIndent: "  ",
                isOptional: true,
                defaultValueLiteral: "nil",
                defaultValueRange: dummyRange(0, 0),
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
                declarationRange: dummyRange(0, 0),
                declarationIndent: "  ",
                isOptional: true,
                defaultValueLiteral: "nil",
                defaultValueRange: dummyRange(0, 0),
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
            ),
            properties: [
              .init(
                filePath: "/virtual/Sources/Document.swift",
                name: "author",
                typeName: "User?",
                nonOptionalTypeName: "User",
                declarationRange: dummyRange(0, 0),
                declarationIndent: "  ",
                isOptional: true,
                defaultValueLiteral: "nil",
                defaultValueRange: dummyRange(0, 0),
                isStored: true,
                isStatic: false,
                hasIgnore: false,
                attribute: nil,
                relationship: .init(
                  range: dummyRange(0, 0),
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
                declarationRange: dummyRange(0, 0),
                declarationIndent: "  ",
                isOptional: true,
                defaultValueLiteral: "nil",
                defaultValueRange: dummyRange(0, 0),
                isStored: true,
                isStatic: false,
                hasIgnore: false,
                attribute: nil,
                relationship: .init(
                  range: dummyRange(0, 0),
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

  @Test("comparator accepts renamed relationship when persistentName matches model")
  func comparatorAcceptsRenamedRelationshipMetadata() {
    let diagnostics = ToolingValidateComparator.compareQuick(
      expected: ToolingModelIR(
        source: ambiguousRelationshipModelIR().source,
        generationPolicy: ambiguousRelationshipModelIR().generationPolicy,
        entities: [
          .init(
            name: "Document",
            managedObjectClassName: "NSManagedObject",
            representedClassName: "Document",
            attributes: [],
            relationships: [
              .init(
                persistentName: "author",
                swiftName: "mainAuthor",
                destinationEntityName: "User",
                inverseRelationshipName: "authoredDocuments",
                cardinality: .toOne,
                isOptional: true,
                minCount: 0,
                maxCount: 1,
                deleteRule: "nullify"
              )
            ],
            compositions: []
          )
        ]
      ),
      actual: .init(
        sourceDirectory: "/virtual/Sources",
        entities: [
          .init(
            filePath: "/virtual/Sources/Document.swift",
            className: "Document",
            objcEntityName: "Document",
            persistentModelArguments: .init(
              generateInit: false,
            ),
            properties: [
              .init(
                filePath: "/virtual/Sources/Document.swift",
                name: "mainAuthor",
                typeName: "User?",
                nonOptionalTypeName: "User",
                declarationRange: dummyRange(0, 0),
                declarationIndent: "  ",
                isOptional: true,
                defaultValueLiteral: "nil",
                defaultValueRange: dummyRange(0, 0),
                isStored: true,
                isStatic: false,
                hasIgnore: false,
                attribute: nil,
                relationship: .init(
                  range: dummyRange(0, 0),
                  persistentName: "author",
                  inversePropertyName: "authoredDocuments",
                  deleteRule: "nullify"
                ),
                relationshipShape: .toOne
              )
            ],
            customMembers: []
          )
        ]
      ),
      level: .conformance
    )

    #expect(diagnostics.isEmpty)
  }

  @Test("comparator emits safe fix for missing relationship annotation")
  func comparatorEmitsSafeFixForMissingRelationshipAnnotation() {
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
            ),
            properties: [
              .init(
                filePath: "/virtual/Sources/Document.swift",
                name: "author",
                typeName: "User?",
                nonOptionalTypeName: "User",
                declarationRange: dummyRange(10, 10),
                declarationIndent: "  ",
                isOptional: true,
                defaultValueLiteral: "nil",
                defaultValueRange: dummyRange(20, 23),
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
                declarationRange: dummyRange(30, 30),
                declarationIndent: "  ",
                isOptional: true,
                defaultValueLiteral: "nil",
                defaultValueRange: dummyRange(40, 43),
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

    let diagnostic = diagnostics.first {
      $0.message.contains("relationship 'Document.author'")
    }
    let fix = diagnostic?.fix
    #expect(fix?.isSafeAutofix == true)
    #expect(
      fix?.edits.first?.replacement
        == #"  @Relationship(inverse: "authoredDocuments", deleteRule: .nullify)"# + "\n"
    )
  }

  @Test("comparator emits relationship count fixes when source omits non-default model counts")
  func comparatorEmitsRelationshipCountFixes() {
    let model = ToolingModelIR(
      source: ambiguousRelationshipModelIR().source,
      generationPolicy: ambiguousRelationshipModelIR().generationPolicy,
      entities: [
        .init(
          name: "Owner",
          managedObjectClassName: "NSManagedObject",
          representedClassName: "Owner",
          attributes: [],
          relationships: [
            .init(
              persistentName: "documents",
              swiftName: "documents",
              destinationEntityName: "Document",
              inverseRelationshipName: "owner",
              cardinality: .toManyUnordered,
              isOptional: true,
              minCount: 1,
              maxCount: 3,
              deleteRule: "nullify"
            )
          ],
          compositions: []
        )
      ]
    )
    let source = ToolingSourceModelIR(
      sourceDirectory: "/virtual/Sources",
      entities: [
        .init(
          filePath: "/virtual/Sources/Owner.swift",
          className: "Owner",
          objcEntityName: "Owner",
          persistentModelArguments: .init(
            generateInit: false,
          ),
          properties: [
            .init(
              filePath: "/virtual/Sources/Owner.swift",
              name: "documents",
              typeName: "Set<Document>",
              nonOptionalTypeName: "Set<Document>",
              declarationRange: dummyRange(40, 60),
              declarationIndent: "  ",
              isOptional: false,
              defaultValueLiteral: nil,
              defaultValueRange: nil,
              isStored: true,
              isStatic: false,
              hasIgnore: false,
              attribute: nil,
              relationship: .init(
                range: dummyRange(0, 39),
                inversePropertyName: "owner",
                deleteRule: "nullify"
              ),
              relationshipShape: .toManyUnordered
            )
          ],
          customMembers: []
        )
      ]
    )

    let diagnostics = ToolingValidateComparator.compareQuick(
      expected: model,
      actual: source,
      level: .conformance
    )

    let diagnostic = diagnostics.first {
      $0.message.contains("minimumModelCount mismatch")
    }
    let fix = diagnostic?.fix
    #expect(fix?.isSafeAutofix == true)
    #expect(
      fix?.edits.first?.replacement
        == #"@Relationship(inverse: "owner", deleteRule: .nullify, minimumModelCount: 1, maximumModelCount: 3)"#
    )
  }

  @Test("comparator accepts required default storage without defaults")
  func comparatorAcceptsRequiredDefaultStorageWithoutDefaults() {
    let diagnostics = ToolingValidateComparator.compareQuick(
      expected: requiredDefaultStorageModelIR(),
      actual: .init(
        sourceDirectory: "/virtual/Sources",
        entities: [
          .init(
            filePath: "/virtual/Sources/Item.swift",
            className: "Item",
            objcEntityName: "Item",
            persistentModelArguments: .init(generateInit: false),
            properties: [
              .init(
                filePath: "/virtual/Sources/Item.swift",
                name: "title",
                typeName: "String",
                nonOptionalTypeName: "String",
                declarationRange: dummyRange(0, 0),
                declarationIndent: "  ",
                isOptional: false,
                defaultValueLiteral: nil,
                defaultValueRange: nil,
                isStored: true,
                isStatic: false,
                hasIgnore: false,
                attribute: nil,
                relationshipShape: nil
              )
            ],
            customMembers: []
          )
        ]
      ),
      level: .conformance
    )

    #expect(diagnostics.isEmpty)
  }

  @Test("comparator flags unexpected default on required default storage without model default")
  func comparatorFlagsUnexpectedDefaultOnRequiredDefaultStorage() {
    let diagnostics = ToolingValidateComparator.compareQuick(
      expected: requiredDefaultStorageModelIR(),
      actual: .init(
        sourceDirectory: "/virtual/Sources",
        entities: [
          .init(
            filePath: "/virtual/Sources/Item.swift",
            className: "Item",
            objcEntityName: "Item",
            persistentModelArguments: .init(generateInit: false),
            properties: [
              .init(
                filePath: "/virtual/Sources/Item.swift",
                name: "title",
                typeName: "String",
                nonOptionalTypeName: "String",
                declarationRange: dummyRange(0, 0),
                declarationIndent: "  ",
                isOptional: false,
                defaultValueLiteral: #""untitled""#,
                defaultValueRange: dummyRange(10, 20),
                isStored: true,
                isStatic: false,
                hasIgnore: false,
                attribute: nil,
                relationshipShape: nil
              )
            ],
            customMembers: []
          )
        ]
      ),
      level: .conformance
    )

    #expect(diagnostics.count == 1)
    #expect(
      diagnostics[0].message.contains(
        "default value mismatch for 'Item.title'. Expected '<missing>', found '\"untitled\"'"
      )
    )
  }

  @Test("comparator can ignore optionality mismatch for optional model attribute")
  func comparatorCanIgnoreOptionalityMismatchForOptionalModelAttribute() {
    let model = ToolingModelIR(
      source: requiredDefaultStorageModelIR().source,
      generationPolicy: requiredDefaultStorageModelIR().generationPolicy,
      entities: [
        .init(
          name: "Item",
          managedObjectClassName: "NSManagedObject",
          representedClassName: "Item",
          attributes: [
            .init(
              persistentName: "title",
              swiftName: "title",
              coreDataAttributeType: "String",
              coreDataPrimitiveType: "String",
              isUnique: false,
              isTransient: false,
              isOptional: true,
              hasModelDefaultValue: false,
              modelDefaultValueLiteral: nil,
              storage: .init(
                method: .default,
                swiftType: "String?",
                nonOptionalSwiftType: "String",
                transformerName: nil,
                decodeFailurePolicy: nil,
                isResolved: true
              )
            )
          ],
          relationships: [],
          compositions: []
        )
      ]
    )
    let source = ToolingSourceModelIR(
      sourceDirectory: "/virtual/Sources",
      entities: [
        .init(
          filePath: "/virtual/Sources/Item.swift",
          className: "Item",
          objcEntityName: "Item",
          persistentModelArguments: .init(generateInit: false),
          properties: [
            .init(
              filePath: "/virtual/Sources/Item.swift",
              name: "title",
              typeName: "String",
              nonOptionalTypeName: "String",
              declarationRange: dummyRange(0, 0),
              declarationIndent: "  ",
              isOptional: false,
              defaultValueLiteral: nil,
              defaultValueRange: nil,
              isStored: true,
              isStatic: false,
              hasIgnore: false,
              attribute: nil,
              relationshipShape: nil
            )
          ],
          customMembers: []
        )
      ]
    )

    let diagnosticsWithoutIgnore = ToolingValidateComparator.compareQuick(
      expected: model,
      actual: source,
      level: .conformance
    )
    #expect(
      diagnosticsWithoutIgnore.contains {
        $0.message.contains("type mismatch for 'Item.title'")
      }
    )

    let diagnosticsWithIgnore = ToolingValidateComparator.compareQuick(
      expected: model,
      actual: source,
      level: .conformance,
      attributeRules: .init(
        entities: [
          "Item": [
            "title": .init(ignoreOptionality: true)
          ]
        ]
      )
    )
    #expect(diagnosticsWithIgnore.isEmpty)
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

private func requiredDefaultStorageModelIR() -> ToolingModelIR {
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
      defaultDecodeFailurePolicy: .fallbackToDefaultValue
    ),
    entities: [
      .init(
        name: "Item",
        managedObjectClassName: "NSManagedObject",
        representedClassName: "Item",
        attributes: [
          .init(
            persistentName: "title",
            swiftName: "title",
            coreDataAttributeType: "String",
            coreDataPrimitiveType: "String",
            isOptional: false,
            hasModelDefaultValue: false,
            modelDefaultValueLiteral: nil,
            storage: .init(
              method: .default,
              swiftType: "String",
              nonOptionalSwiftType: "String",
              transformerName: nil,
              decodeFailurePolicy: nil,
              isResolved: true
            )
          )
        ],
        relationships: [],
        compositions: []
      )
    ]
  )
}

private func dummyRange(_ start: Int, _ end: Int) -> ToolingTextRange {
  .init(startUTF8Offset: start, endUTF8Offset: end)
}
