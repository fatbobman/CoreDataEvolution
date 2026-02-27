import CoreData
import CoreDataEvolution
import Testing

/// Test suite for NSModelActor.withContext functionality.
///
/// These tests verify that `withContext` correctly exposes the actor's
/// managed object context (and container) within the actor's isolation,
/// enabling direct Core Data assertions without going through the actor's
/// higher-level API.
@Suite("withContext Tests")
struct WithContextTests {
  // MARK: - withContext(_ action: (NSManagedObjectContext) throws -> T)

  /// Verifies that `withContext` can fetch objects created through the actor's API.
  @Test("withContext - fetch items after creation")
  func fetchItemsAfterCreation() async throws {
    let stack = TestStack()
    let handler = DataHandler(container: stack.container, viewName: "withContext-fetch")

    // Create two items via the actor's public API
    _ = try await handler.createNemItem(Date())
    _ = try await handler.createNemItem(Date())

    // Use withContext to inspect the persistent store directly
    let count = try await handler.withContext { context in
      let request = Item.fetchRequest()
      return try context.fetch(request).count
    }

    #expect(count == 2)
  }

  /// Verifies that `withContext` reflects the state after a delete operation.
  @Test("withContext - count reflects deletion")
  func countReflectsDeletion() async throws {
    let stack = TestStack()
    let handler = DataHandler(container: stack.container, viewName: "withContext-delete")

    let id = try await handler.createNemItem()
    try await handler.delItem(id)

    let count = try await handler.withContext { context in
      let request = Item.fetchRequest()
      return try context.fetch(request).count
    }

    #expect(count == 0)
  }

  /// Verifies that `withContext` can return a value (not just Void).
  @Test("withContext - returns value from closure")
  func returnsValueFromClosure() async throws {
    let stack = TestStack()
    let handler = DataHandler(container: stack.container, viewName: "withContext-return")

    let timestamp = Date(timeIntervalSinceReferenceDate: 1_000_000)
    _ = try await handler.createNemItem(timestamp)

    let fetched = try await handler.withContext { context -> Date? in
      let request = Item.fetchRequest()
      return try context.fetch(request).first?.timestamp
    }

    #expect(fetched == timestamp)
  }

  /// Verifies that errors thrown inside the closure propagate correctly.
  @Test("withContext - propagates thrown errors")
  func propagatesThrownErrors() async throws {
    struct TestError: Error, Sendable {}

    let stack = TestStack()
    let handler = DataHandler(container: stack.container, viewName: "withContext-error")

    await #expect(throws: TestError.self) {
      try await handler.withContext { _ in
        throw TestError()
      }
    }
  }

  // MARK: - withContext(_ action: (NSManagedObjectContext, NSPersistentContainer) throws -> T)

  /// Verifies that the container overload passes a valid NSPersistentContainer.
  @Test("withContext(container) - container is accessible")
  func containerIsAccessible() async throws {
    let stack = TestStack()
    let handler = DataHandler(container: stack.container, viewName: "withContext-container")

    _ = try await handler.createNemItem()

    // Verify via a fresh background context created from the container
    let countViaNewContext = try await handler.withContext { _, container in
      let verificationContext = container.newBackgroundContext()
      let request = Item.fetchRequest()
      return try verificationContext.fetch(request).count
    }

    #expect(countViaNewContext == 1)
  }

  /// Verifies that the container overload also returns values correctly.
  @Test("withContext(container) - returns value from closure")
  func containerOverloadReturnsValue() async throws {
    let stack = TestStack()
    let handler = DataHandler(container: stack.container, viewName: "withContext-container-return")

    let containerName = try await handler.withContext { _, container in
      container.name
    }

    #expect(containerName == "TestModel")
  }
}
