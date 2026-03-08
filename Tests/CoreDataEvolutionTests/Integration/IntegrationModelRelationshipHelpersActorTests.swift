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
}
