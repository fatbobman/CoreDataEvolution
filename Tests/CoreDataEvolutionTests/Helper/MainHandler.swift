//
//  ------------------------------------------------
//  Original project: CoreDataEvolution
//  Created on 2024/9/20 by Fatbobman(东坡肘子)
//  X: @fatbobman
//  Mastodon: @fatbobman@mastodon.social
//  GitHub: @fatbobman
//  Blog: https://fatbobman.com
//  ------------------------------------------------
//  Copyright © 2024-present Fatbobman. All rights reserved.

import CoreData
import CoreDataEvolution

@MainActor
@NSMainModelActor
final class MainHandler {
  func createNemItem(_ timestamp: Date = Date(), showThread: Bool = false) throws
    -> NSManagedObjectID
  {
    let item = Item(context: modelContext)
    item.timestamp = timestamp
    if showThread {
      print(Thread.current)
    }
    try modelContext.save()
    return item.objectID
  }

  func delItem(_ item: Item) throws {
    modelContext.delete(item)
    try modelContext.save()
  }

  func delItem(_ itemID: NSManagedObjectID) throws {
    guard let item = try modelContext.existingObject(with: itemID) as? Item else {
      fatalError("Can't load model by ID:\(itemID)")
    }
    try delItem(item)
  }

  private func getAllItems() throws -> [Item] {
    let request = Item.fetchRequest()
    return try modelContext.fetch(request)
  }

  func getItemCount() throws -> Int {
    try getAllItems().count
  }
}
