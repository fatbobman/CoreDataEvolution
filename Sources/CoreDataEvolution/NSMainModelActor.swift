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

/// Main-actor protocol used by types expanded from `@NSMainModelActor`.
///
/// The generated type works with `container.viewContext` and is intended for UI-facing Core Data
/// code that should remain on the main actor.
@MainActor
public protocol NSMainModelActor: AnyObject {
  /// The persistent container owned by this main-actor type.
  var modelContainer: NSPersistentContainer { get }
}
extension NSMainModelActor {
  /// The view context exposed by the container.
  public var modelContext: NSManagedObjectContext {
    modelContainer.viewContext
  }

  /// Looks up a managed object by ID and downcasts it to the requested type.
  public subscript<T>(id: NSManagedObjectID, as _: T.Type) -> T? where T: NSManagedObject {
    modelActorExistingObject(in: modelContext, id: id, as: T.self)
  }

  /// Provides direct, synchronous access to the underlying `NSManagedObjectContext`
  /// within the main actor's isolation boundary.
  ///
  /// This matches `NSModelActor.withContext(_:)`, but runs against `viewContext` on the main actor.
  ///
  /// - Parameter action: A synchronous closure that receives the main actor's
  ///   `NSManagedObjectContext`. The return value must conform to `Sendable`.
  /// - Returns: The value produced by `action`.
  /// - Throws: Any error thrown by `action`.
  ///
  /// - Note: Although this method is part of the public API, it is primarily intended
  ///   for testing and debugging. For production writes, prefer dedicated mutation
  ///   methods so that save/rollback logic remains consistent.
  public func withContext<T: Sendable>(
    _ action: (NSManagedObjectContext) throws -> T
  ) throws -> T {
    try withModelContext(modelContext, action)
  }

  /// Provides direct, synchronous access to both the `NSManagedObjectContext` and
  /// the `NSPersistentContainer` within the main actor's isolation boundary.
  ///
  /// This matches `NSModelActor.withContext(_:)`, but runs against `viewContext` on the main actor.
  ///
  /// - Parameter action: A synchronous closure that receives both the main actor's
  ///   `NSManagedObjectContext` and its `NSPersistentContainer`.
  ///   The return value must conform to `Sendable`.
  /// - Returns: The value produced by `action`.
  /// - Throws: Any error thrown by `action`.
  ///
  /// - Note: Although this method is part of the public API, it is primarily intended
  ///   for testing and debugging. For production writes, prefer dedicated mutation
  ///   methods so that save/rollback logic remains consistent.
  public func withContext<T: Sendable>(
    _ action: (NSManagedObjectContext, NSPersistentContainer) throws -> T
  ) throws -> T {
    try withModelContext(modelContext, container: modelContainer, action)
  }
}
