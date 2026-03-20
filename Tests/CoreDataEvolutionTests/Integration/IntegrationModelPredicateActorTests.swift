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

@preconcurrency import CoreDataEvolution
import Foundation
import Testing

@NSModelActor(disableGenerateInit: true)
private actor IntegrationPredicateHandler {
  init(container: NSPersistentContainer) {
    modelContainer = container
    let context = container.newBackgroundContext()
    context.name = "integration-predicate"
    modelExecutor = .init(context: context)
  }

  func seedPredicateData() throws {
    let swift = CDETag(context: modelContext)
    swift.label = "Swift"

    let objc = CDETag(context: modelContext)
    objc.label = "ObjC"

    let empty = CDETag(context: modelContext)
    empty.label = "Empty"

    let alpha = CDEItem(context: modelContext)
    alpha.title = "alpha"
    alpha.priority = 2
    alpha.tag = swift

    let beta = CDEItem(context: modelContext)
    beta.title = "beta"
    beta.priority = 7
    beta.tag = objc

    let orphan = CDEItem(context: modelContext)
    orphan.title = "orphan"

    try modelContext.save()
  }
}

@Suite("Integration Model Predicate Actor Tests")
struct IntegrationModelPredicateActorTests {
  @Test func macroGeneratedPredicateWorksAcrossRelationships() async throws {
    let stack = try IntegrationModelStack()
    let handler = IntegrationPredicateHandler(container: stack.container)

    try await handler.seedPredicateData()

    let result = try await handler.withContext { context in
      let swiftTagRequest = NSFetchRequest<CDETag>(entityName: "CDETag")
      swiftTagRequest.predicate = NSPredicate(format: "label == %@", "Swift")
      let swiftTag = try context.fetch(swiftTagRequest).first!

      let itemsRequest = NSFetchRequest<CDEItem>(entityName: "CDEItem")
      itemsRequest.predicate = CDEItem.path.tag.equals(swiftTag)
      let itemNames = try context.fetch(itemsRequest).map(\.title)

      let tagsRequest = NSFetchRequest<CDETag>(entityName: "CDETag")
      tagsRequest.predicate = CDETag.path.items.any.title.equals("alpha")
      let tags = try context.fetch(tagsRequest)
      let tagLabels = tags.map(\.label)
      let inverseItemCount = tags.first?.items.count ?? 0

      let noneRequest = NSFetchRequest<CDETag>(entityName: "CDETag")
      noneRequest.sortDescriptors = [NSSortDescriptor(key: "label", ascending: true)]
      noneRequest.predicate = CDETag.path.items.none.title.equals("alpha")
      let noneLabels = try context.fetch(noneRequest).map(\.label)

      let allRequest = NSFetchRequest<CDETag>(entityName: "CDETag")
      allRequest.sortDescriptors = [NSSortDescriptor(key: "label", ascending: true)]
      allRequest.predicate = CDETag.path.items.all.priority.greaterThan(3)
      let allLabels = try context.fetch(allRequest).map(\.label)

      let nilRequest = NSFetchRequest<CDEItem>(entityName: "CDEItem")
      nilRequest.predicate = CDEItem.path.tag.isNil()
      let nilTitles = try context.fetch(nilRequest).map(\.title)

      return (itemNames, tagLabels, inverseItemCount, noneLabels, allLabels, nilTitles)
    }

    #expect(result.0 == ["alpha"])
    #expect(result.1 == ["Swift"])
    #expect(result.2 == 1)
    #expect(result.3 == ["Empty", "ObjC"])
    #expect(result.4 == ["Empty", "ObjC"])
    #expect(result.5 == ["orphan"])
  }
}
