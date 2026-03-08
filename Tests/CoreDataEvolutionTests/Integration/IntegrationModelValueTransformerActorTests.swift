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
private actor IntegrationValueTransformerHandler {
  init(container: NSPersistentContainer) {
    modelContainer = container
    let context = container.newBackgroundContext()
    context.name = "integration-valuetransformer"
    modelExecutor = .init(context: context)
  }

  func seedTransformedData() throws {
    let item = CDEItem(context: modelContext)
    item.title = "transform-item"
    item.keywords = ["swift", "coredata", "macro"]
    try modelContext.save()
  }
}

@Suite("Integration Model ValueTransformer Actor Tests")
struct IntegrationModelValueTransformerActorTests {
  @Test func transformedPathExposesPersistentKey() throws {
    #expect(CDEItem.path.keywords.raw == "keywords_payload")
  }

  @Test func transformedStorageRoundTripsAndPersistsRawValue() async throws {
    let stack = IntegrationModelStack()
    let handler = IntegrationValueTransformerHandler(container: stack.container)
    try await handler.seedTransformedData()

    let result = try await handler.withContext { context in
      let request = NSFetchRequest<CDEItem>(entityName: "CDEItem")
      guard let item = try context.fetch(request).first else {
        throw NSError(domain: "Integration", code: 1)
      }

      let rawValue = item.value(forKey: "keywords_payload") as? String
      return (item.keywords, rawValue)
    }

    #expect(result.0 == ["swift", "coredata", "macro"])
    #expect(result.1 == "swift|coredata|macro")
  }
}
