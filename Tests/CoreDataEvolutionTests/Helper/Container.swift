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

import CoreData
import Foundation

final class TestStack: @unchecked Sendable {
  @MainActor var viewContext: NSManagedObjectContext {
    container.viewContext
  }
  
  static let model:NSManagedObjectModel = {
    guard let modelURL = Bundle.module.url(forResource: "TestModel", withExtension: "momd"),
          let model = NSManagedObjectModel(contentsOf: modelURL)
    else {
      fatalError("Can't load DataModel")
    }
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

extension NSManagedObjectModel:@unchecked @retroactive Sendable {}
