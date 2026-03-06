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

@preconcurrency import CoreData
import CoreDataEvolutionToolingCore
import Foundation
import Testing

@Suite("Tooling Core IR Builder Tests")
struct ToolingIRBuilderTests {
  @Test("builder resolves attribute naming, storage, and relationship metadata")
  func builderResolvesAttributeAndRelationshipMetadata() throws {
    let model = makeModel()
    let loadedModel = ToolingLoadedModel(
      model: model,
      resolvedInput: .init(
        originalURL: URL(fileURLWithPath: "/virtual/AppModel.xcdatamodeld"),
        selectedSourceURL: URL(fileURLWithPath: "/virtual/AppModel.xcdatamodeld/V2.xcdatamodel"),
        compiledModelURL: URL(fileURLWithPath: "/virtual/AppModel.momd"),
        kind: .xcdatamodeld,
        selectedVersionName: "V2.xcdatamodel"
      )
    )
    let request = InspectRequest(
      modelPath: "/virtual/AppModel.xcdatamodeld",
      modelVersion: "V2",
      momcBin: nil,
      typeMappings: .init(
        coreDataTypes: [
          ToolingCoreDataPrimitiveType.integer64.rawValue: .init(swiftType: "Int"),
          ToolingCoreDataPrimitiveType.string.rawValue: .init(swiftType: "String"),
          ToolingCoreDataPrimitiveType.binary.rawValue: .init(swiftType: "Data"),
        ]
      ),
      attributeRules: .init(
        entities: [
          "Item": [
            "name": .init(swiftName: "title"),
            "status_raw": .init(
              swiftType: "ItemStatus",
              storageMethod: .raw,
              decodeFailurePolicy: .debugAssertNil
            ),
            "payload": .init(
              storageMethod: .transformed,
              transformerType: "LocationTransformer"
            ),
            "geo_blob": .init(
              swiftType: "GeoPayload",
              storageMethod: .composition
            ),
          ]
        ]
      ),
      defaultDecodeFailurePolicy: .fallbackToDefaultValue
    )

    let result = ToolingIRBuilder.build(
      from: loadedModel,
      request: request
    )

    #expect(result.modelIR.source.selectedVersionName == "V2.xcdatamodel")
    #expect(result.modelIR.generationPolicy.relationshipSetterPolicy == .warning)

    let item = try #require(result.modelIR.entities.first(where: { $0.name == "Item" }))
    let title = try #require(item.attributes.first(where: { $0.persistentName == "name" }))
    #expect(title.swiftName == "title")
    #expect(title.storage.method == .default)
    #expect(title.storage.swiftType == "String")
    #expect(title.storage.isResolved)
    #expect(title.hasModelDefaultValue)
    #expect(title.modelDefaultValueLiteral == #""""#)

    let status = try #require(item.attributes.first(where: { $0.persistentName == "status_raw" }))
    #expect(status.storage.method == .raw)
    #expect(status.storage.nonOptionalSwiftType == "ItemStatus")
    #expect(status.storage.decodeFailurePolicy == .debugAssertNil)
    #expect(status.hasModelDefaultValue == false)

    let payload = try #require(item.attributes.first(where: { $0.persistentName == "payload" }))
    #expect(payload.storage.method == .transformed)
    #expect(payload.storage.swiftType == nil)
    #expect(payload.storage.isResolved == false)

    let composition = try #require(item.compositions.first(where: { $0.swiftName == "geo_blob" }))
    #expect(composition.swiftType == "GeoPayload")

    let tags = try #require(item.relationships.first(where: { $0.persistentName == "tags" }))
    #expect(tags.cardinality == .toManyUnordered)
    #expect(tags.destinationEntityName == "Tag")
    #expect(tags.inverseRelationshipName == "item")

    #expect(
      result.diagnostics.contains(where: {
        $0.message.contains("storageMethod 'transformed'") && $0.severity == .warning
      })
    )
  }

  @Test("builder warns about missing attribute rules that no longer match the model")
  func builderWarnsAboutUnusedAttributeRules() throws {
    let loadedModel = ToolingLoadedModel(
      model: makeModel(),
      resolvedInput: .init(
        originalURL: URL(fileURLWithPath: "/virtual/AppModel.xcdatamodeld"),
        selectedSourceURL: URL(fileURLWithPath: "/virtual/AppModel.xcdatamodeld/V1.xcdatamodel"),
        compiledModelURL: URL(fileURLWithPath: "/virtual/AppModel.momd"),
        kind: .xcdatamodeld,
        selectedVersionName: "V1.xcdatamodel"
      )
    )
    let request = InspectRequest(
      modelPath: "/virtual/AppModel.xcdatamodeld",
      modelVersion: nil,
      momcBin: nil,
      attributeRules: .init(
        entities: [
          "Ghost": [
            "name": .init(swiftName: "title")
          ],
          "Item": [
            "missing_field": .init(swiftName: "title")
          ],
        ]
      )
    )

    let result = ToolingIRBuilder.build(
      from: loadedModel,
      request: request
    )

    #expect(
      result.diagnostics.contains(where: { $0.message.contains("missing entity 'Ghost'") })
    )
    #expect(
      result.diagnostics.contains(where: {
        $0.message.contains("missing attribute 'Item.missing_field'")
      })
    )
  }

  private func makeModel() -> NSManagedObjectModel {
    let name = NSAttributeDescription()
    name.name = "name"
    name.attributeType = .stringAttributeType
    name.isOptional = false
    name.defaultValue = ""

    let statusRaw = NSAttributeDescription()
    statusRaw.name = "status_raw"
    statusRaw.attributeType = .integer64AttributeType
    statusRaw.isOptional = false

    let payload = NSAttributeDescription()
    payload.name = "payload"
    payload.attributeType = .transformableAttributeType
    payload.isOptional = true

    let geoBlob = NSAttributeDescription()
    geoBlob.name = "geo_blob"
    geoBlob.attributeType = .binaryDataAttributeType
    geoBlob.isOptional = false

    let tagName = NSAttributeDescription()
    tagName.name = "tag_name"
    tagName.attributeType = .stringAttributeType
    tagName.isOptional = false

    let item = NSEntityDescription()
    item.name = "Item"
    item.managedObjectClassName = "NSManagedObject"

    let tag = NSEntityDescription()
    tag.name = "Tag"
    tag.managedObjectClassName = "NSManagedObject"

    let tags = NSRelationshipDescription()
    tags.name = "tags"
    tags.destinationEntity = tag
    tags.minCount = 0
    tags.maxCount = 0
    tags.isOptional = true
    tags.isOrdered = false
    tags.deleteRule = .nullifyDeleteRule

    let itemRef = NSRelationshipDescription()
    itemRef.name = "item"
    itemRef.destinationEntity = item
    itemRef.minCount = 0
    itemRef.maxCount = 1
    itemRef.isOptional = true
    itemRef.deleteRule = .nullifyDeleteRule

    tags.inverseRelationship = itemRef
    itemRef.inverseRelationship = tags

    item.properties = [name, statusRaw, payload, geoBlob, tags]
    tag.properties = [tagName, itemRef]

    let model = NSManagedObjectModel()
    model.entities = [item, tag]
    return model
  }
}
