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

@Suite("Tooling Core Source Renderer Tests")
struct ToolingSourceRendererTests {
  @Test("renderer emits macro style entity source")
  func rendererEmitsMacroStyleEntitySource() throws {
    let modelIR = ToolingModelIR(
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
        generateInit: true,
        defaultDecodeFailurePolicy: .fallbackToDefaultValue
      ),
      entities: [
        .init(
          name: "Item",
          managedObjectClassName: "NSManagedObject",
          representedClassName: "Item",
          attributes: [
            .init(
              persistentName: "name",
              swiftName: "title",
              coreDataAttributeType: "String",
              coreDataPrimitiveType: "String",
              isOptional: false,
              hasModelDefaultValue: true,
              modelDefaultValueLiteral: #""""#,
              storage: .init(
                method: .default,
                swiftType: "String",
                nonOptionalSwiftType: "String",
                transformerName: nil,
                decodeFailurePolicy: nil,
                isResolved: true
              )
            ),
            .init(
              persistentName: "status_raw",
              swiftName: "status",
              coreDataAttributeType: "Integer 64",
              coreDataPrimitiveType: "Integer 64",
              isOptional: true,
              hasModelDefaultValue: false,
              modelDefaultValueLiteral: nil,
              storage: .init(
                method: .raw,
                swiftType: "ItemStatus?",
                nonOptionalSwiftType: "ItemStatus",
                transformerName: nil,
                decodeFailurePolicy: .debugAssertNil,
                isResolved: true
              )
            ),
            .init(
              persistentName: "location_blob",
              swiftName: "location_blob",
              coreDataAttributeType: "Binary",
              coreDataPrimitiveType: "Binary",
              isOptional: true,
              hasModelDefaultValue: false,
              modelDefaultValueLiteral: nil,
              storage: .init(
                method: .composition,
                swiftType: "ItemLocation?",
                nonOptionalSwiftType: "ItemLocation",
                transformerName: nil,
                decodeFailurePolicy: nil,
                isResolved: true
              )
            ),
          ],
          relationships: [
            .init(
              persistentName: "tags",
              swiftName: "tags",
              destinationEntityName: "Tag",
              inverseRelationshipName: "item",
              cardinality: .toManyUnordered,
              isOptional: true,
              minCount: 0,
              maxCount: 0,
              deleteRule: "nullify"
            )
          ],
          compositions: [
            .init(
              swiftName: "location",
              swiftType: "ItemLocation",
              persistentFields: ["location_blob"]
            )
          ]
        )
      ]
    )

    let source = try ToolingSourceRenderer.renderSources(
      from: modelIR,
      header: "// GENERATED"
    ).first?.contents
    let rendered = try #require(source)

    #expect(rendered.contains("// GENERATED"))
    #expect(rendered.contains("@objc(Item)"))
    #expect(rendered.contains("@PersistentModel("))
    #expect(rendered.contains("generateToManyCount: false") == false)
    #expect(rendered.contains(#"@Attribute(persistentName: "name")"#))
    #expect(
      rendered.contains(
        #"@Attribute(persistentName: "status_raw", storageMethod: .raw, decodeFailurePolicy: .debugAssertNil)"#
      ))
    #expect(
      rendered.contains(
        #"@Attribute(persistentName: "location_blob", storageMethod: .composition)"#))
    #expect(rendered.contains("var title: String = \"\""))
    #expect(rendered.contains("var status: ItemStatus? = nil"))
    #expect(rendered.contains("var location: ItemLocation? = nil"))
    #expect(rendered.contains("var tags: Set<Tag>"))
    #expect(rendered.contains("convenience init("))
    #expect(rendered.contains("extension Item: PersistentEntity {}") == false)
  }

  @Test("renderer emits generateToManyCount when disabled")
  func rendererEmitsGenerateToManyCountWhenDisabled() throws {
    let modelIR = ToolingModelIR(
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
        generateToManyCount: false,
        defaultDecodeFailurePolicy: .fallbackToDefaultValue
      ),
      entities: [
        .init(
          name: "Item",
          managedObjectClassName: "NSManagedObject",
          representedClassName: "Item",
          attributes: [],
          relationships: [],
          compositions: []
        )
      ]
    )

    let source = try ToolingSourceRenderer.renderSources(from: modelIR).first?.contents
    let rendered = try #require(source)

    #expect(rendered.contains("@PersistentModel(generateToManyCount: false)"))
  }

  @Test("renderer emits relationship metadata for relationships")
  func rendererEmitsRelationshipMetadataForRelationships() throws {
    let modelIR = ToolingModelIR(
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
              persistentName: "document_author",
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

    let source = try ToolingSourceRenderer.renderSources(from: modelIR).first?.contents
    let rendered = try #require(source)

    #expect(
      rendered.contains(
        #"@Relationship(persistentName: "document_author", inverse: "authoredDocuments", deleteRule: .nullify)"#
      ))
    #expect(
      rendered.contains(#"@Relationship(inverse: "editedDocuments", deleteRule: .nullify)"#))
  }

  @Test("renderer emits explicit relationship min/max counts when model differs from defaults")
  func rendererEmitsRelationshipModelCounts() throws {
    let modelIR = ToolingModelIR(
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
              deleteRule: "deny"
            )
          ],
          compositions: []
        )
      ]
    )

    let source = try ToolingSourceRenderer.renderSources(from: modelIR).first?.contents
    let rendered = try #require(source)

    #expect(
      rendered.contains(
        #"@Relationship(inverse: "owner", deleteRule: .deny, minimumModelCount: 1, maximumModelCount: 3)"#
      )
    )
  }

  @Test("renderer rejects non-optional custom storage without a synthesizeable default")
  func rendererRejectsUnsupportedNonOptionalDefault() throws {
    let modelIR = ToolingModelIR(
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
              persistentName: "config_blob",
              swiftName: "config",
              coreDataAttributeType: "Binary",
              coreDataPrimitiveType: "Binary",
              isOptional: false,
              hasModelDefaultValue: true,
              modelDefaultValueLiteral: "Data(base64Encoded: \"AA==\")!",
              storage: .init(
                method: .codable,
                swiftType: "ItemConfig",
                nonOptionalSwiftType: "ItemConfig",
                transformerName: nil,
                decodeFailurePolicy: .fallbackToDefaultValue,
                isResolved: true
              )
            )
          ],
          relationships: [],
          compositions: []
        )
      ]
    )

    do {
      _ = try ToolingSourceRenderer.renderSources(from: modelIR)
      Issue.record("Expected renderer to reject unsupported non-optional custom default.")
    } catch let error as ToolingFailure {
      #expect(error.code == .configInvalid)
    }
  }

  @Test("renderer emits non-optional raw storage using model default literal")
  func rendererEmitsNonOptionalRawStorageDefault() throws {
    let modelIR = ToolingModelIR(
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
              persistentName: "status_raw",
              swiftName: "status",
              coreDataAttributeType: "Integer 32",
              coreDataPrimitiveType: "Int32",
              isOptional: false,
              hasModelDefaultValue: true,
              modelDefaultValueLiteral: "0",
              storage: .init(
                method: .raw,
                swiftType: "ItemStatus",
                nonOptionalSwiftType: "ItemStatus",
                transformerName: nil,
                decodeFailurePolicy: .fallbackToDefaultValue,
                isResolved: true
              )
            )
          ],
          relationships: [],
          compositions: []
        )
      ]
    )

    let source = try #require(ToolingSourceRenderer.renderSources(from: modelIR).first?.contents)

    #expect(source.contains(#"var status: ItemStatus = ItemStatus(rawValue: 0)!"#))
  }

  @Test("renderer emits required raw storage without an initializer when model default is absent")
  func rendererEmitsRequiredRawStorageWithoutInitializer() throws {
    let modelIR = ToolingModelIR(
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
              persistentName: "status_raw",
              swiftName: "status",
              coreDataAttributeType: "Integer 32",
              coreDataPrimitiveType: "Int32",
              isOptional: false,
              hasModelDefaultValue: false,
              modelDefaultValueLiteral: nil,
              storage: .init(
                method: .raw,
                swiftType: "ItemStatus",
                nonOptionalSwiftType: "ItemStatus",
                transformerName: nil,
                decodeFailurePolicy: .fallbackToDefaultValue,
                isResolved: true
              )
            )
          ],
          relationships: [],
          compositions: []
        )
      ]
    )

    let source = try #require(ToolingSourceRenderer.renderSources(from: modelIR).first?.contents)

    #expect(source.contains("var status: ItemStatus\n"))
    #expect(source.contains("var status: ItemStatus =") == false)
  }

  @Test(
    "renderer emits required default storage without an initializer when model default is absent")
  func rendererEmitsRequiredDefaultStorageWithoutInitializer() throws {
    let modelIR = ToolingModelIR(
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
              persistentName: "name",
              swiftName: "name",
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

    let source = try #require(ToolingSourceRenderer.renderSources(from: modelIR).first?.contents)

    #expect(source.contains("var name: String\n"))
    #expect(source.contains("var name: String =") == false)
  }

  @Test("renderer rejects non-optional relationships")
  func rendererRejectsNonOptionalRelationship() throws {
    let modelIR = ToolingModelIR(
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
          attributes: [],
          relationships: [
            .init(
              persistentName: "tags",
              swiftName: "tags",
              destinationEntityName: "Tag",
              inverseRelationshipName: "item",
              cardinality: .toManyUnordered,
              isOptional: false,
              minCount: 1,
              maxCount: 0,
              deleteRule: "nullify"
            )
          ],
          compositions: []
        )
      ]
    )

    do {
      _ = try ToolingSourceRenderer.renderSources(from: modelIR)
      Issue.record("Expected renderer to reject non-optional relationship.")
    } catch let error as ToolingFailure {
      #expect(error.code == .configInvalid)
      #expect(error.message.contains("to be optional"))
    }
  }

  @Test("renderer rejects relationships without inverse")
  func rendererRejectsRelationshipWithoutInverse() throws {
    let modelIR = ToolingModelIR(
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
          attributes: [],
          relationships: [
            .init(
              persistentName: "owner",
              swiftName: "owner",
              destinationEntityName: "Owner",
              inverseRelationshipName: nil,
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
    )

    do {
      _ = try ToolingSourceRenderer.renderSources(from: modelIR)
      Issue.record("Expected renderer to reject relationship without inverse.")
    } catch let error as ToolingFailure {
      #expect(error.code == .configInvalid)
      #expect(error.message.contains("inverse relationship"))
    }
  }
}
