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

/// A protocol that defines the properties and methods for accessing a Core Data model in a main actor context.
@MainActor
public protocol NSMainModelActor: AnyObject {
    /// The NSPersistentContainer for the NSMainModelActor
    var modelContainer: NSPersistentContainer { get }
}

extension NSMainModelActor {
    /// The view context for the NSMainModelActor
    public var modelContext: NSManagedObjectContext {
        modelContainer.viewContext
    }

    /// Returns the model for the specified identifier, downcast to the appropriate class.
    public subscript<T>(id: NSManagedObjectID, as _: T.Type) -> T? where T: NSManagedObject {
        try? modelContext.existingObject(with: id) as? T
    }
}
