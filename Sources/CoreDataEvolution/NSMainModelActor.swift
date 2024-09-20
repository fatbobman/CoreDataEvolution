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

@MainActor
public protocol NSMainModelActor {
  /// The NSPersistentContainer for the NSMainModelActor
  var modelContainer: NSPersistentContainer { get }
}

public extension NSMainModelActor {
  /// The view context
  var modelContext: NSManagedObjectContext {
    modelContainer.viewContext
  }
  
  /// Returns the model for the specified identifier, downcast to the appropriate class.
  subscript<T>(id: NSManagedObjectID, as _: T.Type) -> T? where T: NSManagedObject {
    try? modelContext.existingObject(with: id) as? T
  }
}
