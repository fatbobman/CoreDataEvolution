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
  /// 1. Deriving a unique file name from `testName` (or from call-site `#fileID-#function`
  ///    when `testName` is not provided).
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
  ///     // testName defaults to #fileID-#function — no need to pass it explicitly
  ///     let container = NSPersistentContainer.makeTest(model: MyModel.objectModel)
  ///     let handler = DataHandler(container: container)
  ///     // … test body …
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - model: The `NSManagedObjectModel` describing your Core Data schema.
  ///   - testName: Optional explicit store name override. If omitted, a name is derived from
  ///     call-site `#fileID` and `#function`.
  ///   - fileID: Pass-through call-site file identity used when `testName` is omitted.
  ///   - function: Pass-through call-site function identity used when `testName` is omitted.
  ///   - subDirectory: The temporary sub-directory used to store the SQLite files.
  ///     Defaults to `"CoreDataEvolutionTestTemp"`.
  /// - Returns: A fully loaded `NSPersistentContainer` ready for use.
  ///
  /// - Note: Store files are written to `URL.temporaryDirectory/<subDirectory>/`.
  ///   They are removed on the *next* call with the same `testName`, not immediately after the
  ///   test completes, so they can be inspected for debugging if needed.
  public static func makeTest(
    model: NSManagedObjectModel,
    testName: String = "",
    fileID: String = #fileID,
    function: String = #function,
    subDirectory: String = "CoreDataEvolutionTestTemp"
  ) -> NSPersistentContainer {
    let resolvedTestName = testName.isEmpty ? "\(fileID)-\(function)" : testName
    let testDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(
      subDirectory)

    if !FileManager.default.fileExists(atPath: testDirectory.path) {
      try? FileManager.default.createDirectory(
        at: testDirectory,
        withIntermediateDirectories: true
      )
    }

    let sanitizedStoreName = sanitizeStoreFileName(resolvedTestName)
    let storeURL = testDirectory.appendingPathComponent("\(sanitizedStoreName).sqlite")

    // Remove stale SQLite files (main + WAL journal sidecar files) before loading.
    for suffix in ["", "-shm", "-wal"] {
      let path = storeURL.path + suffix
      if FileManager.default.fileExists(atPath: path) {
        try? FileManager.default.removeItem(atPath: path)
      }
    }

    let container = NSPersistentContainer(name: resolvedTestName, managedObjectModel: model)

    let description = NSPersistentStoreDescription(url: storeURL)
    description.shouldAddStoreAsynchronously = false
    container.persistentStoreDescriptions = [description]

    container.loadPersistentStores { _, error in
      if let error {
        fatalError("Failed to load test store '\(resolvedTestName)': \(error)")
      }
    }

    return container
  }

  private static func sanitizeStoreFileName(_ rawName: String) -> String {
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
    let sanitized = rawName.unicodeScalars.map { scalar in
      allowed.contains(scalar) ? String(scalar) : "_"
    }.joined()

    var collapsed = ""
    collapsed.reserveCapacity(sanitized.count)
    var previousWasUnderscore = false
    for character in sanitized {
      if character == "_" {
        if !previousWasUnderscore {
          collapsed.append(character)
        }
        previousWasUnderscore = true
      } else {
        collapsed.append(character)
        previousWasUnderscore = false
      }
    }

    let trimmed = collapsed.trimmingCharacters(in: CharacterSet(charactersIn: "._-"))
    return trimmed.isEmpty ? "CoreDataEvolutionTestStore" : trimmed
  }
}
