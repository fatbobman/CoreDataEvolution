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

/// A protocol that defines the properties and methods for accessing a Core Data model in a main actor context.
import CoreData

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

  /// Provides direct, synchronous access to the underlying `NSManagedObjectContext`
  /// within the main actor's isolation boundary.
  ///
  /// Use this method when you need to perform raw Core Data operations that aren't
  /// covered by the type's higher-level API — most commonly in unit tests to inspect
  /// the persistent store state after a write operation.
  ///
  /// The closure runs **synchronously** on the main actor context. There is no
  /// additional scheduling overhead; the call returns only after the closure completes.
  ///
  /// **Typical usage in tests:**
  /// ```swift
  /// @MainActor
  /// @Test func verifyMainHandlerState() throws {
  ///     let container = NSPersistentContainer.makeTest(model: MySchema.objectModel)
  ///     let handler = MainHandler(modelContainer: container)
  ///     _ = try handler.createItem()
  ///
  ///     let count = try handler.withContext { context in
  ///         let request = Item.fetchRequest()
  ///         return try context.fetch(request).count
  ///     }
  ///     #expect(count == 1)
  /// }
  /// ```
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
    try action(modelContext)
  }

  /// Provides direct, synchronous access to both the `NSManagedObjectContext` and
  /// the `NSPersistentContainer` within the main actor's isolation boundary.
  ///
  /// This overload is useful when the closure needs to cross-reference the container —
  /// for example, to inspect store metadata or create a verification context in tests.
  ///
  /// **Typical usage in tests:**
  /// ```swift
  /// @MainActor
  /// @Test func verifyWithContainerOverload() throws {
  ///     let container = NSPersistentContainer.makeTest(model: MySchema.objectModel)
  ///     let handler = MainHandler(modelContainer: container)
  ///
  ///     let count = try handler.withContext { _, container in
  ///         let verification = container.newBackgroundContext()
  ///         let request = Item.fetchRequest()
  ///         return try verification.fetch(request).count
  ///     }
  ///     #expect(count == 0)
  /// }
  /// ```
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
    try action(modelContext, modelContainer)
  }
}
