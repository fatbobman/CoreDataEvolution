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

  /// Runs a synchronous closure against `viewContext` on the main actor.
  ///
  /// This is the UI-facing counterpart to `NSModelActor.withContext(_:)`.
  public func withContext<T: Sendable>(
    _ action: (NSManagedObjectContext) throws -> T
  ) throws -> T {
    try withModelContext(modelContext, action)
  }

  /// Runs a synchronous closure against `viewContext` and the owning container.
  ///
  /// Use this overload for UI tests or debugging flows that also need container-level access.
  public func withContext<T: Sendable>(
    _ action: (NSManagedObjectContext, NSPersistentContainer) throws -> T
  ) throws -> T {
    try withModelContext(modelContext, container: modelContainer, action)
  }
}
