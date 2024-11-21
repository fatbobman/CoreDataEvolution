//
//  ------------------------------------------------
//  Original project: CoreDataEvolution
//  Created on 2024/11/21 by Fatbobman(东坡肘子)
//  X: @fatbobman
//  Mastodon: @fatbobman@mastodon.social
//  GitHub: @fatbobman
//  Blog: https://fatbobman.com
//  ------------------------------------------------
//  Copyright © 2024-present Fatbobman. All rights reserved.

@preconcurrency import CoreData
import CoreDataEvolution
import Foundation
import Testing

/// A helper class which causes all threads to wait until an expected number have reached
/// the synchronization point, and then allows all to continue.
/// This is used to allow us to reliably exercise the race condition to be demonstrated.
final class ThreadBarrier: @unchecked Sendable {
    private let condition = NSCondition()
    private var threadCount: Int
    private var currentCount = 0

    init(threadCount: Int) {
        self.threadCount = threadCount
    }

    func wait() {
        condition.lock()
        defer { condition.unlock() }

        currentCount += 1

        if currentCount < threadCount {
            // Wait until all threads reach the barrier
            condition.wait()
        } else {
            // Last thread wakes up all waiting threads
            condition.broadcast()
        }
    }
}

/// An actor which will oinvoke an inner method on another instance of the
/// same type. To demonstrate the deadlock we will create two actors which each
/// enter their own code (taking the performAndWait lock) and then try to call each other.
protocol MutuallyInvokingActor: Actor {}
extension MutuallyInvokingActor {
    func outer(barrier: ThreadBarrier, other: any MutuallyInvokingActor) async {
        print("Start Outer")
        barrier.wait()
        print("After Barrier")
        await other.inner()
        print("End Outer")
    }

    func inner() {
        print("Inner")
    }
}

/// This is a normal actor which will not produce a deadlock, because the normal actor
/// `enqueue` method just queues up a method to call later
actor NormalActor: MutuallyInvokingActor {}

/// This `NSModelActor` will deadlock because enqueue calls actor methods synchronously
@NSModelActor
actor DeadlockActor: MutuallyInvokingActor {}

@Test
func deadLockTest() async throws {
    /// Run the two actors in parallel to attempt to demonstrate the deadlock
    func attemptDeadlock(_ actorA: MutuallyInvokingActor, _ actorB: MutuallyInvokingActor) async {
        print("Attempting to demonstrate actor deadlock")
        let barrier = ThreadBarrier(threadCount: 2)

        // Invoke DeadlockActor.outer on both actors in parallel
        async let result1 = actorA.outer(barrier: barrier, other: actorB)
        async let result2 = actorB.outer(barrier: barrier, other: actorA)

        _ = await (result1, result2)
        print("Comlete - actors did not deadlock")
    }

    // With normal actors demonstrate the program does not deadlock
    print("Running mutually invoking code between two normal actors")
    let normalActorA = NormalActor()
    let normalAactorB = NormalActor()
    await attemptDeadlock(normalActorA, normalAactorB)

    let stack = TestStack()
    let container = stack.container

    print("Running mutually invoking code between two NSModelActors")
    let deadlockActorA = DeadlockActor(container: container)
    let deadlockAactorB = DeadlockActor(container: container)
    await attemptDeadlock(deadlockActorA, deadlockAactorB)
}
