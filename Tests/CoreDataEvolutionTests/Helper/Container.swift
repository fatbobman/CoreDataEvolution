//
//  ------------------------------------------------
//  Original project: CoreDataEvolution
//  Created on 2024/8/22 by Fatbobman(东坡肘子)
//  X: @fatbobman
//  Mastodon: @fatbobman@mastodon.social
//  GitHub: @fatbobman
//  Blog: https://fatbobman.com
//  ------------------------------------------------
//  Copyright © 2024-present Fatbobman. All rights reserved.

@preconcurrency import CoreData
import Foundation

final class TestStack {
  @MainActor var viewContext: NSManagedObjectContext {
    container.viewContext
  }

  static let model: NSManagedObjectModel = {
    let model = NSManagedObjectModel()
    let itemEntity = NSEntityDescription()
    itemEntity.name = "Item"
    itemEntity.managedObjectClassName = NSStringFromClass(Item.self)

    let timestampAttribute = NSAttributeDescription()
    timestampAttribute.name = "timestamp"
    timestampAttribute.attributeType = .dateAttributeType
    timestampAttribute.isOptional = true

    itemEntity.properties = [timestampAttribute]
    model.entities = [itemEntity]
    return model
  }()

  let container: NSPersistentContainer

  init(url: URL = URL(fileURLWithPath: "/dev/null")) {
    container = NSPersistentContainer(name: "TestModel", managedObjectModel: Self.model)
    container.persistentStoreDescriptions.first!.url = url
    container.loadPersistentStores { _, error in
      if let error = error as NSError? {
        fatalError("Unresolved error \(error), \(error.userInfo)")
      }
    }
    container.viewContext.automaticallyMergesChangesFromParent = true
  }
}
