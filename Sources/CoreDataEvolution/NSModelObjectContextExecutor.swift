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

import _Concurrency
import CoreData

/// A class that coordinates access to the model actor.
public final class NSModelObjectContextExecutor: @unchecked Sendable, SerialExecutor {
    public final let context: NSManagedObjectContext
    public init(context: NSManagedObjectContext) {
        self.context = context
    }

    public func enqueue(_ job: consuming ExecutorJob) {
        let unownedJob = UnownedJob(job)
        let unownedExecutor = asUnownedSerialExecutor()
        context.performAndWait {
            unownedJob.runSynchronously(on: unownedExecutor)
        }
    }

    public func asUnownedSerialExecutor() -> UnownedSerialExecutor {
        UnownedSerialExecutor(ordinary: self)
    }
}
