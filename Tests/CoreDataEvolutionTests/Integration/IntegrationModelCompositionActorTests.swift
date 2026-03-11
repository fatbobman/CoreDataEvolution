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
private actor IntegrationCompositionHandler {
  init(container: NSPersistentContainer) {
    modelContainer = container
    let context = container.newBackgroundContext()
    context.name = "integration-composition"
    modelExecutor = .init(context: context)
  }

  func seedCompositionData() throws {
    let item = CDEItem(context: modelContext)
    item.title = "composition-item"
    item.location = .init(x: 12.5, y: 8.0)
    try modelContext.save()
  }
}

@Suite("Integration Model Composition Actor Tests")
struct IntegrationModelCompositionActorTests {
  @Test func compositionFieldTableAndPredicateKeyMappingAreAvailable() throws {
    #expect(CDEItem.__cdMeta(forSwiftPath: "location")?.kind == .composition)
    #expect(CDEItem.__cdPersistentPath(forSwiftPath: "location.x") == "location.x")
    #expect(CDEItem.__cdPersistentPath(forSwiftPath: "location.y") == "location.y")

    let predicate = CDFilterField<CDEItem, Double>(swiftPath: ["location", "x"]).greaterThan(10)
    #expect(predicate.predicateFormat.contains("location.x >"))
  }

  @Test func schemaBackedCompositionUsesCoreDataCompositeAttribute() throws {
    let model = IntegrationModelStack.model
    guard let entity = model.entitiesByName["CDEItem"],
      let attribute = entity.attributesByName["location"]
    else {
      Issue.record("Expected integration model to contain CDEItem.location.")
      return
    }

    #expect(attribute.attributeType == .compositeAttributeType)
  }

  @Test func compositionStorageRoundTripsAgainstCompositeAttribute() async throws {
    let stack = try IntegrationModelStack()
    let handler = IntegrationCompositionHandler(container: stack.container)
    try await handler.seedCompositionData()

    let result = try await handler.withContext { context in
      let request = NSFetchRequest<CDEItem>(entityName: "CDEItem")
      guard let item = try context.fetch(request).first else {
        throw NSError(domain: "Integration", code: 1)
      }

      let rawValue = item.value(forKey: "location") as? NSDictionary
      let rawX = (rawValue?["x"] as? NSNumber)?.doubleValue
      let rawY = (rawValue?["y"] as? NSNumber)?.doubleValue

      return (item.location, rawX, rawY)
    }

    #expect(result.0 == .init(x: 12.5, y: 8.0))
    #expect(result.1 == 12.5)
    #expect(result.2 == 8.0)
  }
}
