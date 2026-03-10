//
//  ------------------------------------------------
//  Original project: CoreDataEvolution
//  Created on 2026/3/10 by Fatbobman(东坡肘子)
//  X: @fatbobman
//  Mastodon: @fatbobman@mastodon.social
//  GitHub: @fatbobman
//  Blog: https://fatbobman.com
//  ------------------------------------------------
//  Copyright © 2024-present Fatbobman. All rights reserved.

import SwiftParser
import SwiftSyntax
import SwiftSyntaxMacroExpansion
import Testing

@testable import CoreDataEvolutionMacros

@Suite("Member Generation Helpers")
struct MemberGenerationHelperTests {
  @Test("persistent model path entries preserve path kinds and persistent names")
  func persistentModelPathEntriesPreserveKindsAndNames() {
    let model = PersistentModelAnalysis(
      properties: [
        .attribute(
          .init(
            propertyName: "title",
            typeName: "String",
            nonOptionalTypeName: "String",
            persistentName: "display_name",
            isOptional: false,
            storageMethod: .default,
            defaultValueExpression: "\"\"",
            isUnique: false,
            isTransient: false
          )
        ),
        .attribute(
          .init(
            propertyName: "location",
            typeName: "GeoPoint?",
            nonOptionalTypeName: "GeoPoint",
            persistentName: "geo_blob",
            isOptional: true,
            storageMethod: .composition,
            defaultValueExpression: "nil",
            isUnique: false,
            isTransient: false
          )
        ),
        .relationship(
          .init(
            propertyName: "owner",
            persistentName: "task_owner",
            targetTypeName: "User",
            inverseName: "tasks",
            deleteRule: .nullify,
            minimumModelCount: nil,
            maximumModelCount: nil,
            kind: .toOne
          )
        ),
        .relationship(
          .init(
            propertyName: "tags",
            persistentName: "oldtags",
            targetTypeName: "Tag",
            inverseName: "items",
            deleteRule: .cascade,
            minimumModelCount: 0,
            maximumModelCount: 0,
            kind: .toManySet
          )
        ),
      ]
    )

    let entries = collectPersistentModelPathEntries(
      accessModifier: "public ",
      modelTypeName: "Task",
      model: model
    )

    #expect(entries.map(\.propertyName) == ["title", "location", "owner", "tags"])
    #expect(
      entries.map(\.kind) == [.attribute, .composition, .toOneRelationship, .toManyRelationship])
    #expect(entries[0].typeReference == "CoreDataEvolution.CDPath<Task, String>")
    #expect(
      entries[1].typeReference == "CoreDataEvolution.CDCompositionPath<Task, GeoPoint?, GeoPoint>")
    #expect(entries[0].declaration.contains("persistentPath: [\"display_name\"]"))
    #expect(entries[1].declaration.contains("persistentPath: [\"geo_blob\"]"))
    #expect(entries[2].declaration.contains("persistentPath: [\"task_owner\"]"))
    #expect(entries[3].declaration.contains("persistentPath: [\"oldtags\"]"))
  }

  @Test("persistent model field table rendering merges composition and relationship metadata")
  func persistentModelFieldTableRenderingMergesCompositionAndRelationships() {
    let model = PersistentModelAnalysis(
      properties: [
        .attribute(
          .init(
            propertyName: "title",
            typeName: "String",
            nonOptionalTypeName: "String",
            persistentName: "display_name",
            isOptional: false,
            storageMethod: .default,
            defaultValueExpression: "\"\"",
            isUnique: false,
            isTransient: false
          )
        ),
        .attribute(
          .init(
            propertyName: "location",
            typeName: "GeoPoint?",
            nonOptionalTypeName: "GeoPoint",
            persistentName: "geo_blob",
            isOptional: true,
            storageMethod: .composition,
            defaultValueExpression: "nil",
            isUnique: false,
            isTransient: false
          )
        ),
        .relationship(
          .init(
            propertyName: "tags",
            persistentName: "oldtags",
            targetTypeName: "Tag",
            inverseName: "items",
            deleteRule: .cascade,
            minimumModelCount: 0,
            maximumModelCount: 0,
            kind: .toManySet
          )
        ),
      ]
    )

    let rendering = collectPersistentModelFieldTableRendering(
      accessModifier: "public ",
      model: model
    )

    #expect(rendering.relationshipProjectionTableDecl.contains("\"title\": .init("))
    #expect(rendering.relationshipProjectionTableDecl.contains("\"location\": .init("))
    #expect(
      rendering.relationshipProjectionTableDecl.contains(
        "modelPersistentPathPrefix: [\"geo_blob\"]")
    )
    #expect(rendering.fieldTableDecl.contains("\"tags\": .init("))
    #expect(rendering.fieldTableDecl.contains("persistentPath: [\"oldtags\"]"))
    #expect(
      rendering.fieldTableDecl.contains("makeToManyFieldEntries(")
    )
  }

  @Test("composition analysis preserves field names, persistent names, and defaults")
  func compositionAnalysisPreservesNamesAndDefaults() throws {
    let source = Parser.parse(
      source: """
        @Composition
        struct GeoPoint {
          @CompositionField(persistentName: "lat")
          var latitude: Double = 0

          @CompositionField(persistentName: "lng")
          var longitude: Double? = nil
        }
        """
    )
    let structDecl = try #require(
      source.statements.first?.item.as(StructDeclSyntax.self)
    )
    let context = BasicMacroExpansionContext(sourceFiles: [
      source: .init(moduleName: "CoreDataEvolutionMacroTests", fullFilePath: "GeoPoint.swift")
    ])

    let analysis = analyzeCompositionFields(in: structDecl, context: context)

    #expect(analysis.hasError == false)
    #expect(analysis.fields.map(\.name) == ["latitude", "longitude"])
    #expect(analysis.fields.map(\.persistentName) == ["lat", "lng"])
    #expect(analysis.fields.map(\.typeName) == ["Double", "Double?"])
    #expect(analysis.fields.map(\.defaultValueExpression) == ["0", "nil"])
  }

  @Test("composition rendering uses persistent names in paths and runtime fields")
  func compositionRenderingUsesPersistentNames() {
    let fields = [
      CompositionField(
        name: "latitude",
        persistentName: "lat",
        typeName: "Double",
        decodeCastTypeName: "Double",
        isOptional: false,
        defaultValueExpression: "0"
      ),
      CompositionField(
        name: "longitude",
        persistentName: "lng",
        typeName: "Double?",
        decodeCastTypeName: "Double",
        isOptional: true,
        defaultValueExpression: "nil"
      ),
    ]

    let rendering = makeCompositionRenderingParts(
      accessModifier: "public ",
      compositionTypeName: "GeoPoint",
      fields: fields
    )

    #expect(
      rendering.fieldTableBody.contains(
        "\"latitude\": .init(swiftPath: [\"latitude\"], persistentPath: [\"lat\"])"))
    #expect(rendering.pathBody.contains("persistentPath: [\"lat\"]"))
    #expect(rendering.pathBody.contains("persistentPath: [\"lng\"]"))
    #expect(rendering.runtimeFieldBody.contains("persistentName: \"lat\""))
    #expect(rendering.runtimeFieldBody.contains("persistentName: \"lng\""))
    #expect(rendering.encodeBody.contains("dictionary[\"lat\"] = latitude"))
    #expect(rendering.encodeBody.contains("dictionary[\"lng\"] = longitude"))
    #expect(rendering.decodeBody.contains("dictionary[\"lat\"]"))
    #expect(rendering.decodeBody.contains("dictionary[\"lng\"]"))
  }
}
