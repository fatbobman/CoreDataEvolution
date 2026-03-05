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

@preconcurrency import CoreData
import CoreDataEvolution
import Foundation
import Testing

@NSModelActor(disableGenerateInit: true)
actor IntegrationPredicateHandler {
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

    let alpha = CDEItem(context: modelContext)
    alpha.name = "alpha"
    alpha.priority = 2
    alpha.tag = swift

    let beta = CDEItem(context: modelContext)
    beta.name = "beta"
    beta.priority = 7
    beta.tag = objc

    try modelContext.save()
  }
}

@Suite("Integration Model Predicate Actor Tests")
struct IntegrationModelPredicateActorTests {
  @Test func macroGeneratedPredicateWorksAcrossRelationships() async throws {
    let stack = IntegrationModelStack()
    let handler = IntegrationPredicateHandler(container: stack.container)

    try await handler.seedPredicateData()

    let result = try await handler.withContext { context in
      let itemsRequest = NSFetchRequest<CDEItem>(entityName: "CDEItem")
      itemsRequest.predicate = CDEItem.path.tag.label.equals("Swift")
      let itemNames = try context.fetch(itemsRequest).map(\.name)

      let tagsRequest = NSFetchRequest<CDETag>(entityName: "CDETag")
      tagsRequest.predicate = CDETag.path.items.any.name.equals("alpha")
      let tagLabels = try context.fetch(tagsRequest).map(\.label)

      return (itemNames, tagLabels)
    }

    #expect(result.0 == ["alpha"])
    #expect(result.1 == ["Swift"])
  }
}
