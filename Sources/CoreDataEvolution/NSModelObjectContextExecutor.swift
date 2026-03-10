import CoreData
import _Concurrency

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

/// Serial executor that runs actor jobs through `NSManagedObjectContext.perform`.
///
/// `@NSModelActor` uses this executor to keep all Core Data work serialized onto the context that
/// backs the generated actor instance.
public final class NSModelObjectContextExecutor: @unchecked Sendable, SerialExecutor {
  public final let context: NSManagedObjectContext
  public init(context: NSManagedObjectContext) {
    self.context = context
  }

  public func enqueue(_ job: UnownedJob) {
    let unownedExecutor = asUnownedSerialExecutor()
    context.perform {
      job.runSynchronously(on: unownedExecutor)
    }
  }

  public func asUnownedSerialExecutor() -> UnownedSerialExecutor {
    UnownedSerialExecutor(ordinary: self)
  }
}
