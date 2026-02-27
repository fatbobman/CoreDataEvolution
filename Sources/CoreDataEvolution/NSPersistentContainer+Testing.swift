import CoreData
import Foundation

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

extension NSPersistentContainer {
  /// Creates an `NSPersistentContainer` backed by an isolated on-disk SQLite store for use in
  /// unit tests.
  ///
  /// Each call produces a **fresh, independent store** by:
  /// 1. Deriving a unique file name from `testName` (pass `#function` for automatic naming).
  /// 2. Deleting any pre-existing SQLite files at that path (`.sqlite`, `.sqlite-shm`,
  ///    `.sqlite-wal`) before loading the store.
  ///
  /// This avoids the two most common pitfalls of test stores:
  /// - **`/dev/null` (shared in-memory)**: All tests sharing the same `/dev/null` URL read and
  ///   write the same in-memory store. Parallel test execution can cause data leakage and
  ///   deadlocks.
  /// - **Named in-memory stores**: SQLite's WAL journal and shared-memory sidecar files can
  ///   linger between runs when using a named in-memory store, leading to phantom data.
  ///
  /// **Typical usage:**
  /// ```swift
  /// @Test func createItem() async throws {
  ///     // testName defaults to #function — no need to pass it explicitly
  ///     let container = NSPersistentContainer.makeTest(model: MyModel.objectModel)
  ///     let handler = DataHandler(container: container)
  ///     // … test body …
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - model: The `NSManagedObjectModel` describing your Core Data schema.
  ///   - testName: A unique name for this test's store file. Pass `#function` to use the
  ///     calling test function's name automatically.
  ///   - subDirectory: The temporary sub-directory used to store the SQLite files.
  ///     Defaults to `"CoreDataEvolutionTestTemp"`.
  /// - Returns: A fully loaded `NSPersistentContainer` ready for use.
  ///
  /// - Note: Store files are written to `URL.temporaryDirectory/<subDirectory>/`.
  ///   They are removed on the *next* call with the same `testName`, not immediately after the
  ///   test completes, so they can be inspected for debugging if needed.
  public static func makeTest(
    model: NSManagedObjectModel,
    testName: String = #function,
    subDirectory: String = "CoreDataEvolutionTestTemp"
  ) -> NSPersistentContainer {
    let testDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(
      subDirectory)

    if !FileManager.default.fileExists(atPath: testDirectory.path) {
      try? FileManager.default.createDirectory(
        at: testDirectory,
        withIntermediateDirectories: true
      )
    }

    let storeURL = testDirectory.appendingPathComponent("\(testName).sqlite")

    // Remove stale SQLite files (main + WAL journal sidecar files) before loading.
    for suffix in ["", "-shm", "-wal"] {
      let path = storeURL.path + suffix
      if FileManager.default.fileExists(atPath: path) {
        try? FileManager.default.removeItem(atPath: path)
      }
    }

    let container = NSPersistentContainer(name: testName, managedObjectModel: model)

    let description = NSPersistentStoreDescription(url: storeURL)
    description.shouldAddStoreAsynchronously = false
    container.persistentStoreDescriptions = [description]

    container.loadPersistentStores { _, error in
      if let error {
        fatalError("Failed to load test store '\(testName)': \(error)")
      }
    }

    return container
  }
}
