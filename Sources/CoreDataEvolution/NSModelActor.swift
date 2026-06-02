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

#if compiler(>=6.2)
  @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
  extension NSModelActor {
    /// Saves actor-isolated changes with property-level Observation metadata.
    ///
    /// Direct `modelContext.save()` calls still merge through Core Data, but they bypass CDE metadata
    /// staging and therefore fall back to object-scoped invalidation in the observation domain.
    public func saveObservedChanges(in observation: CDEObservationDomain) async throws {
      let token = CDEObservationSaveToken()
      let changes = collectChangedObservationFieldSets(from: modelContext.updatedObjects)

      // Keep snapshot, staging, and save in one actor job. Suspending here would let reentrant actor
      // work change `modelContext` after the field snapshot but before the save commits.
      observation.stagePendingChangesFromProducer(token: token, changesByObjectID: changes)
      do {
        try modelContext.save()
      } catch {
        observation.rollbackPendingChangesFromProducer(token: token)
        modelContext.rollback()
        throw error
      }
    }
  }
#endif
