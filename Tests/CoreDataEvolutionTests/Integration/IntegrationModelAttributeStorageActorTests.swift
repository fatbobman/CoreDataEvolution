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
private actor IntegrationAttributeStorageHandler {
  init(container: NSPersistentContainer) {
    modelContainer = container
    let context = container.newBackgroundContext()
    context.name = "integration-attribute-storage"
    modelExecutor = .init(context: context)
  }

  func seedStorageData() throws {
    let item = CDEItem(context: modelContext)
    item.title = "mapped-title"
    item.priority = 3
    item.status = .active
    item.config = .init(isPinned: true, note: "hello")
    try modelContext.save()
  }
}

@Suite("Integration Model Attribute Storage Actor Tests")
struct IntegrationModelAttributeStorageActorTests {
  @Test func renamedAndStoragePathsExposePersistentKeys() throws {
    #expect(CDEItem.path.title.raw == "name")
    #expect(CDEItem.path.status.raw == "status_raw")
    #expect(CDEItem.path.config.raw == "config_blob")
  }

  @Test func originalNameRawAndCodableMapToPersistentFields() async throws {
    let stack = IntegrationModelStack()
    let handler = IntegrationAttributeStorageHandler(container: stack.container)
    try await handler.seedStorageData()

    let result = try await handler.withContext { context in
      let request = NSFetchRequest<CDEItem>(entityName: "CDEItem")
      guard let item = try context.fetch(request).first else {
        throw NSError(domain: "Integration", code: 1)
      }

      let persistentName = item.value(forKey: "name") as? String
      let persistentStatus = item.value(forKey: "status_raw") as? String
      let persistentConfigData = item.value(forKey: "config_blob") as? Data

      let decodedConfig: CDEItemConfig? = {
        guard let data = persistentConfigData else { return nil }
        return try? JSONDecoder().decode(CDEItemConfig.self, from: data)
      }()

      return (
        item.title,
        item.status,
        item.config,
        persistentName,
        persistentStatus,
        decodedConfig
      )
    }

    #expect(result.0 == "mapped-title")
    #expect(result.1 == .active)
    #expect(result.2 == .init(isPinned: true, note: "hello"))
    #expect(result.3 == "mapped-title")
    #expect(result.4 == CDEItemStatus.active.rawValue)
    #expect(result.5 == .init(isPinned: true, note: "hello"))
  }
}
