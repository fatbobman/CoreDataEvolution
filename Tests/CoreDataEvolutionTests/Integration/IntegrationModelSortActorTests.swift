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
private actor IntegrationSortHandler {
  init(container: NSPersistentContainer) {
    modelContainer = container
    let context = container.newBackgroundContext()
    context.name = "integration-sort"
    modelExecutor = .init(context: context)
  }

  func seedSortData() throws {
    let swift = CDETag(context: modelContext)
    swift.label = "swift"

    let low = CDEItem(context: modelContext)
    low.name = "alpha"
    low.priority = 1
    low.tag = swift

    let high = CDEItem(context: modelContext)
    high.name = "beta"
    high.priority = 9
    high.tag = swift

    try modelContext.save()
  }
}

@Suite("Integration Model Sort Actor Tests")
struct IntegrationModelSortActorTests {
  @Test func macroGeneratedSortWorksAgainstCompiledModel() async throws {
    let stack = IntegrationModelStack()
    let handler = IntegrationSortHandler(container: stack.container)

    try await handler.seedSortData()

    let sortedNames = try await handler.withContext { context in
      let request = NSFetchRequest<CDEItem>(entityName: "CDEItem")
      request.sortDescriptors = [
        try NSSortDescriptor(CDEItem.self, path: CDEItem.path.priority, order: .desc)
      ]
      return try context.fetch(request).map(\.name)
    }

    let firstLabel = try await handler.withContext { context in
      let request = NSFetchRequest<CDEItem>(entityName: "CDEItem")
      request.sortDescriptors = [
        try NSSortDescriptor(CDEItem.self, path: CDEItem.path.priority, order: .desc)
      ]
      return try context.fetch(request).first?.tag?.label
    }

    #expect(sortedNames == ["beta", "alpha"])
    #expect(firstLabel == "swift")
  }
}
