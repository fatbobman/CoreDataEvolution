//
//  ------------------------------------------------
//  Original project: CoreDataEvolution
//  Created on 2024/4/9 by Fatbobman(东坡肘子)
//  X: @fatbobman
//  Mastodon: @fatbobman@mastodon.social
//  GitHub: @fatbobman
//  Blog: https://fatbobman.com
//  ------------------------------------------------
//  Copyright © 2024-present Fatbobman. All rights reserved.

import _Concurrency
import CoreData
import Foundation

/// A protocol that defines the properties and methods for accessing a Core Data model in a model actor context.
public protocol NSModelActor: Actor {
    /// The NSPersistentContainer for the NSModelActor
    nonisolated var modelContainer: NSPersistentContainer { get }

    /// The executor that coordinates access to the model actor.
    nonisolated var modelExecutor: NSModelObjectContextExecutor { get }
}

extension NSModelActor {
    /// The optimized, unonwned reference to the model actor's executor.
    public nonisolated var unownedExecutor: UnownedSerialExecutor {
        modelExecutor.asUnownedSerialExecutor()
    }

    /// The context that serializes any code running on the model actor.
    public var modelContext: NSManagedObjectContext {
        modelExecutor.context
    }

    /// Returns the model for the specified identifier, downcast to the appropriate class.
    public subscript<T>(id: NSManagedObjectID, as _: T.Type) -> T? where T: NSManagedObject {
        try? modelContext.existingObject(with: id) as? T
    }
}
