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

import Foundation
import Testing

@testable import CoreDataEvolution

@NSModelActor(disableGenerateInit: true)
actor RuntimeDebugHandler {
  init(container: NSPersistentContainer, contextName: String = "RuntimeDebugHandler") {
    modelContainer = container
    let context = container.newBackgroundContext()
    context.name = contextName
    modelExecutor = .init(context: context)
  }

  func createItem(title: String, tagName: String) throws -> NSManagedObjectID {
    let tagEntity = try requireEntity("RuntimeSchemaTag")
    let tag = RuntimeSchemaTag(entity: tagEntity, insertInto: modelContext)
    tag.name = tagName

    let itemEntity = try requireEntity("RuntimeSchemaItem")
    let item = RuntimeSchemaItem(entity: itemEntity, insertInto: modelContext)
    item.title = title
    item.addToTags(tag)

    try modelContext.save()
    return item.objectID
  }

  private func requireEntity(_ name: String) throws -> NSEntityDescription {
    guard let entity = NSEntityDescription.entity(forEntityName: name, in: modelContext) else {
      struct MissingEntityError: LocalizedError {
        let name: String
        var errorDescription: String? {
          "Missing runtime entity '\(name)' in model context."
        }
      }
      throw MissingEntityError(name: name)
    }
    return entity
  }
}

struct RuntimeDebugAPITests {
  @Test("makeTest surfaces store loading failures as thrown errors")
  func makeTestThrowsInsteadOfAbortingOnStoreLoadFailure() throws {
    struct SyntheticLoadFailure: LocalizedError {
      var errorDescription: String? { "synthetic store load failure" }
    }

    do {
      _ = try NSPersistentContainer.makeTest(
        model: TestStack.model,
        testName: "InjectedStoreLoadFailure",
        loadStoresUsing: { _ in SyntheticLoadFailure() }
      )
      Issue.record("Expected makeTest to throw when the injected loader reports a failure.")
    } catch let error as CDTestContainerError {
      switch error {
      case .failedToLoadPersistentStore(let testName, let storePath, _):
        #expect(testName == "InjectedStoreLoadFailure")
        #expect(storePath.contains("InjectedStoreLoadFailure.sqlite"))
      default:
        Issue.record("Unexpected CDTestContainerError case: \(error)")
      }
    }
  }

  @Test("runtime schema collection and model builder support variadic entry points")
  func variadicRuntimeConveniencesBuildExpectedArtifacts() throws {
    let schemas = CDRuntimeSchemaCollection.entitySchemas(
      RuntimeSchemaItem.self,
      RuntimeSchemaTag.self
    )
    #expect(schemas.count == 2)

    let model = try CDRuntimeModelBuilder.makeModel(
      RuntimeSchemaItem.self,
      RuntimeSchemaTag.self
    )
    #expect(model.entities.count == 2)

    let convenienceModel = try NSManagedObjectModel.makeRuntimeModel(
      RuntimeSchemaItem.self,
      RuntimeSchemaTag.self
    )
    #expect(convenienceModel.entities.count == 2)
  }

  @MainActor
  @Test("runtime model stack keeps schema, model, and container together")
  func runtimeModelStackExposesTestingConveniences() throws {
    let stack = try CDRuntimeModelStack(
      modelTypes: RuntimeSchemaItem.self,
      RuntimeSchemaTag.self,
      testName: "RuntimeModelStackConvenience"
    )

    #expect(stack.schemas.map(\.entityName) == ["RuntimeSchemaItem", "RuntimeSchemaTag"])
    #expect(stack.model.entitiesByName["RuntimeSchemaItem"] != nil)
    #expect(stack.viewContext.automaticallyMergesChangesFromParent)

    let backgroundContext = stack.newBackgroundContext()
    #expect(
      backgroundContext.persistentStoreCoordinator === stack.container.persistentStoreCoordinator)
  }

  @Test("runtime model stack works with NSModelActor handlers")
  func runtimeModelStackSupportsActorBasedTests() async throws {
    let stack = try CDRuntimeModelStack(
      modelTypes: RuntimeSchemaItem.self,
      RuntimeSchemaTag.self,
      testName: "RuntimeModelActorRoundTrip"
    )
    let handler = RuntimeDebugHandler(container: stack.container)
    let itemID = try await handler.createItem(title: "runtime", tagName: "macro")

    let fetchedTitle = try await handler.withContext { context -> String? in
      let item = try context.existingObject(with: itemID) as? RuntimeSchemaItem
      return item?.title
    }
    #expect(fetchedTitle == "runtime")

    let tagCount = try await handler.withContext { context in
      let request = NSFetchRequest<RuntimeSchemaTag>(entityName: "RuntimeSchemaTag")
      return try context.count(for: request)
    }
    #expect(tagCount == 1)
  }

  @MainActor
  @Test("runtime container convenience supports variadic model type input")
  func runtimeContainerVariadicConvenienceLoadsStore() throws {
    let container = try NSPersistentContainer.makeRuntimeTest(
      modelTypes: RuntimeSchemaItem.self,
      RuntimeSchemaTag.self,
      testName: "RuntimeContainerVariadic"
    )

    #expect(container.managedObjectModel.entitiesByName["RuntimeSchemaItem"] != nil)
    #expect(container.viewContext.automaticallyMergesChangesFromParent == false)
  }
}
