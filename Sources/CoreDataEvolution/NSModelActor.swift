import CoreData
/// A protocol that defines the properties and methods for accessing a Core Data model in a model actor context.
import Foundation
import _Concurrency

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

  /// Provides direct, synchronous access to the underlying `NSManagedObjectContext`
  /// within the actor's isolation boundary.
  ///
  /// Use this method when you need to perform raw Core Data operations that aren't
  /// covered by the actor's higher-level API — most commonly in unit tests to inspect
  /// the persistent store state after a write operation.
  ///
  /// The closure runs **synchronously** on the actor's context. There is no scheduling
  /// overhead; the call returns only after the closure completes.
  ///
  /// **Typical usage in tests:**
  /// ```swift
  /// try await handler.withContext { context in
  ///     let request = Item.fetchRequest()
  ///     let items = try context.fetch(request)
  ///     #expect(items.count == 1)
  /// }
  /// ```
  ///
  /// - Parameter action: A synchronous closure that receives the actor's
  ///   `NSManagedObjectContext`. The return value must conform to `Sendable`.
  /// - Returns: The value produced by `action`.
  /// - Throws: Any error thrown by `action`.
  ///
  /// - Note: Although this method is part of the public API, it is primarily intended
  ///   for testing and debugging. For production writes, prefer the actor's dedicated
  ///   mutation methods so that save/rollback logic remains consistent.
  public func withContext<T: Sendable>(
    _ action: (NSManagedObjectContext) throws -> T
  ) throws -> T {
    try action(modelContext)
  }

  /// Provides direct, synchronous access to both the `NSManagedObjectContext` and
  /// the `NSPersistentContainer` within the actor's isolation boundary.
  ///
  /// This overload is useful when the closure needs to cross-reference the container —
  /// for example, to merge changes from another context, inspect store metadata, or
  /// set up a second context for comparison during tests.
  ///
  /// **Typical usage in tests:**
  /// ```swift
  /// try await handler.withContext { context, container in
  ///     // Verify via a fresh context that the data was actually persisted
  ///     let verification = container.newBackgroundContext()
  ///     let request = Item.fetchRequest()
  ///     let items = try verification.fetch(request)
  ///     #expect(items.count == 1)
  /// }
  /// ```
  ///
  /// - Parameter action: A synchronous closure that receives both the actor's
  ///   `NSManagedObjectContext` and its `NSPersistentContainer`.
  ///   The return value must conform to `Sendable`.
  /// - Returns: The value produced by `action`.
  /// - Throws: Any error thrown by `action`.
  ///
  /// - Note: Although this method is part of the public API, it is primarily intended
  ///   for testing and debugging. For production writes, prefer the actor's dedicated
  ///   mutation methods so that save/rollback logic remains consistent.
  public func withContext<T: Sendable>(
    _ action: (NSManagedObjectContext, NSPersistentContainer) throws -> T
  ) throws -> T {
    try action(modelContext, modelContainer)
  }
}
