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
private actor IntegrationRelationshipHelperHandler {
  init(container: NSPersistentContainer) {
    modelContainer = container
    let context = container.newBackgroundContext()
    context.name = "integration-relationship-helper"
    modelExecutor = .init(context: context)
  }

  func runRelationshipHelperFlow() throws -> (Int, Bool, Int, Bool) {
    let tag = CDETag(context: modelContext)
    tag.label = "helpers"

    let first = CDEItem(context: modelContext)
    first.title = "first"
    let second = CDEItem(context: modelContext)
    second.title = "second"

    tag.addToItems(first)
    tag.addToItems(second)
    let countAfterAdd = tag.items.count
    let inverseAfterAdd = first.tag === tag && second.tag === tag

    tag.removeFromItems(second)
    let countAfterRemove = tag.items.count
    let inverseAfterRemove = second.tag == nil

    try modelContext.save()
    return (
      countAfterAdd,
      inverseAfterAdd,
      countAfterRemove,
      inverseAfterRemove
    )
  }

  func runRelationshipBatchHelperFlow() throws -> (Int, Bool, Int, Bool) {
    let tag = CDETag(context: modelContext)
    tag.label = "batch"

    let first = CDEItem(context: modelContext)
    first.title = "first"
    let second = CDEItem(context: modelContext)
    second.title = "second"
    let third = CDEItem(context: modelContext)
    third.title = "third"

    tag.addToItems(Set([first, second]))
    let countAfterBatchAdd = tag.items.count
    let inverseAfterBatchAdd = first.tag === tag && second.tag === tag

    tag.addToItems(third)
    tag.removeFromItems(Set([first, third]))
    let countAfterBatchRemove = tag.items.count
    let inverseAfterBatchRemove = first.tag == nil && third.tag == nil && second.tag === tag

    try modelContext.save()
    return (
      countAfterBatchAdd,
      inverseAfterBatchAdd,
      countAfterBatchRemove,
      inverseAfterBatchRemove
    )
  }
}

@objc(RuntimeOrderedTag)
@PersistentModel
private final class RuntimeOrderedTag: NSManagedObject {
  var name: String = ""
  @Relationship(inverse: "tag", deleteRule: .nullify)
  var items: [RuntimeOrderedItem]
}

@objc(RuntimeOrderedItem)
@PersistentModel
private final class RuntimeOrderedItem: NSManagedObject {
  var title: String = ""
  @Relationship(inverse: "items", deleteRule: .nullify)
  var tag: RuntimeOrderedTag?
}

@NSModelActor(disableGenerateInit: true)
private actor OrderedRelationshipHelperHandler {
  init(container: NSPersistentContainer) {
    modelContainer = container
    let context = container.newBackgroundContext()
    context.name = "ordered-relationship-helper"
    modelExecutor = .init(context: context)
  }

  func runOrderedRelationshipHelperFlow() throws -> ([String], Bool, [String], Bool) {
    let tagEntity = try requireEntity("RuntimeOrderedTag")
    let tag = RuntimeOrderedTag(entity: tagEntity, insertInto: modelContext)
    tag.name = "ordered"

    let firstEntity = try requireEntity("RuntimeOrderedItem")
    let first = RuntimeOrderedItem(entity: firstEntity, insertInto: modelContext)
    first.title = "first"

    let secondEntity = try requireEntity("RuntimeOrderedItem")
    let second = RuntimeOrderedItem(entity: secondEntity, insertInto: modelContext)
    second.title = "second"

    let thirdEntity = try requireEntity("RuntimeOrderedItem")
    let third = RuntimeOrderedItem(entity: thirdEntity, insertInto: modelContext)
    third.title = "third"

    let fourthEntity = try requireEntity("RuntimeOrderedItem")
    let fourth = RuntimeOrderedItem(entity: fourthEntity, insertInto: modelContext)
    fourth.title = "fourth"

    tag.addToItems([second, third])
    tag.insertIntoItems(first, at: 0)
    tag.addToItems(fourth)
    let titlesAfterInsert = tag.items.map(\.title)
    let inverseAfterInsert = [first, second, third, fourth].allSatisfy { $0.tag === tag }

    tag.removeFromItems([second, fourth])
    let titlesAfterRemove = tag.items.map(\.title)
    let inverseAfterRemove = second.tag == nil && fourth.tag == nil && first.tag === tag

    try modelContext.save()
    return (
      titlesAfterInsert,
      inverseAfterInsert,
      titlesAfterRemove,
      inverseAfterRemove
    )
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

@Suite("Integration Model Relationship Helper Actor Tests")
struct IntegrationModelRelationshipHelpersActorTests {
  @Test func toManyRelationshipHelpersMutateBothSides() async throws {
    let stack = IntegrationModelStack()
    let handler = IntegrationRelationshipHelperHandler(container: stack.container)

    let result = try await handler.runRelationshipHelperFlow()
    #expect(result.0 == 2)
    #expect(result.1)
    #expect(result.2 == 1)
    #expect(result.3)
  }

  @Test func toManyRelationshipBatchHelpersMutateBothSides() async throws {
    let stack = IntegrationModelStack()
    let handler = IntegrationRelationshipHelperHandler(container: stack.container)

    let result = try await handler.runRelationshipBatchHelperFlow()
    #expect(result.0 == 2)
    #expect(result.1)
    #expect(result.2 == 1)
    #expect(result.3)
  }

  @Test func orderedRelationshipHelpersPreserveOrderAndInverseState() async throws {
    let container = try NSPersistentContainer.makeRuntimeTest(
      modelTypes: RuntimeOrderedTag.self,
      RuntimeOrderedItem.self,
      testName: "OrderedRelationshipHelpers"
    )
    let handler = OrderedRelationshipHelperHandler(container: container)

    let result = try await handler.runOrderedRelationshipHelperFlow()
    #expect(result.0 == ["first", "second", "third", "fourth"])
    #expect(result.1)
    #expect(result.2 == ["first", "third"])
    #expect(result.3)
  }
}
