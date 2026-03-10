import CoreData
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

/// Actor protocol used by types expanded from `@NSModelActor`.
///
/// The actor isolates all Core Data work onto a serial executor backed by
/// `NSManagedObjectContext.perform`.
public protocol NSModelActor: Actor {
  /// The persistent container owned by this actor.
  nonisolated var modelContainer: NSPersistentContainer { get }

  /// The custom executor that serializes access to the actor's Core Data context.
  nonisolated var modelExecutor: NSModelObjectContextExecutor { get }
}
extension NSModelActor {
  /// The unowned serial executor used by the actor runtime.
  public nonisolated var unownedExecutor: UnownedSerialExecutor {
    modelExecutor.asUnownedSerialExecutor()
  }

  /// The context bound to the actor's serial executor.
  public var modelContext: NSManagedObjectContext {
    modelExecutor.context
  }

  /// Looks up a managed object by ID and downcasts it to the requested type.
  public subscript<T>(id: NSManagedObjectID, as _: T.Type) -> T? where T: NSManagedObject {
    modelActorExistingObject(in: modelContext, id: id, as: T.self)
  }

  /// Runs a synchronous closure against the actor-isolated Core Data context.
  ///
  /// Use this escape hatch for tests, debugging, or small pieces of raw Core Data work that do
  /// not justify a dedicated actor API.
  public func withContext<T: Sendable>(
    _ action: (NSManagedObjectContext) throws -> T
  ) throws -> T {
    try withModelContext(modelContext, action)
  }

  /// Runs a synchronous closure against the actor-isolated context and container.
  ///
  /// Prefer this overload when the operation needs the container as well as the context, such as
  /// setting up a second verification context in tests.
  public func withContext<T: Sendable>(
    _ action: (NSManagedObjectContext, NSPersistentContainer) throws -> T
  ) throws -> T {
    try withModelContext(modelContext, container: modelContainer, action)
  }
}
