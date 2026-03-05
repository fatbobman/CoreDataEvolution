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

@Suite("Integration Model Tests")
struct IntegrationModelTests {
  @MainActor
  @Test func macroGeneratedSortWorksAgainstCompiledModel() throws {
    let stack = IntegrationModelStack()
    let context = stack.container.viewContext

    let swift = CDETag(context: context)
    swift.label = "swift"

    let low = CDEItem(context: context)
    low.name = "alpha"
    low.priority = 1
    low.tag = swift

    let high = CDEItem(context: context)
    high.name = "beta"
    high.priority = 9
    high.tag = swift

    try context.save()

    let request = NSFetchRequest<CDEItem>(entityName: "CDEItem")
    request.sortDescriptors = [
      try NSSortDescriptor(CDEItem.self, path: CDEItem.path.priority, order: .desc)
    ]
    let result = try context.fetch(request)

    #expect(result.map(\.name) == ["beta", "alpha"])
    #expect(result.first?.tag?.label == "swift")
  }

  @MainActor
  @Test func macroGeneratedPredicateWorksAcrossRelationships() throws {
    let stack = IntegrationModelStack()
    let context = stack.container.viewContext

    let swift = CDETag(context: context)
    swift.label = "Swift"

    let objc = CDETag(context: context)
    objc.label = "ObjC"

    let alpha = CDEItem(context: context)
    alpha.name = "alpha"
    alpha.priority = 2
    alpha.tag = swift

    let beta = CDEItem(context: context)
    beta.name = "beta"
    beta.priority = 7
    beta.tag = objc

    try context.save()

    let itemsRequest = NSFetchRequest<CDEItem>(entityName: "CDEItem")
    itemsRequest.predicate = CDEItem.path.tag.label.equals("Swift")
    let itemMatches = try context.fetch(itemsRequest)
    #expect(itemMatches.count == 1)
    #expect(itemMatches.first?.name == "alpha")

    let tagsRequest = NSFetchRequest<CDETag>(entityName: "CDETag")
    tagsRequest.predicate = CDETag.path.items.any.name.equals("alpha")
    let tagMatches = try context.fetch(tagsRequest)
    #expect(tagMatches.count == 1)
    #expect(tagMatches.first?.label == "Swift")
  }
}
