//
//  ------------------------------------------------
//  Original project: CoreDataEvolution
//  Created on 2024/10/30 by Fatbobman(东坡肘子)
//  X: @fatbobman
//  Mastodon: @fatbobman@mastodon.social
//  GitHub: @fatbobman
//  Blog: https://fatbobman.com
//  ------------------------------------------------
//  Copyright © 2024-present Fatbobman. All rights reserved.

import CoreData
import Foundation

/// Shared helpers used by both actor-flavored Core Data facades.
///
/// Both public protocols intentionally expose the same lookup and `withContext` behavior. The only
/// runtime difference is how they source `modelContext`.
func modelActorExistingObject<T: NSManagedObject>(
  in context: NSManagedObjectContext,
  id: NSManagedObjectID,
  as _: T.Type
) -> T? {
  try? context.existingObject(with: id) as? T
}

func withModelContext<T: Sendable>(
  _ context: NSManagedObjectContext,
  _ action: (NSManagedObjectContext) throws -> T
) throws -> T {
  try action(context)
}

func withModelContext<T: Sendable>(
  _ context: NSManagedObjectContext,
  container: NSPersistentContainer,
  _ action: (NSManagedObjectContext, NSPersistentContainer) throws -> T
) throws -> T {
  try action(context, container)
}
