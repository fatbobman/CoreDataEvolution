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

public enum CDTestContainerError: LocalizedError, Sendable, Equatable {
  case failedToCreateStoreDirectory(path: String, reason: String)
  case failedToRemoveStaleStoreFile(path: String, reason: String)
  case failedToLoadPersistentStore(testName: String, storePath: String, reason: String)

  public var errorDescription: String? {
    switch self {
    case .failedToCreateStoreDirectory(let path, let reason):
      return "Failed to create test store directory at '\(path)': \(reason)"
    case .failedToRemoveStaleStoreFile(let path, let reason):
      return "Failed to remove stale test store file at '\(path)': \(reason)"
    case .failedToLoadPersistentStore(let testName, let storePath, let reason):
      return "Failed to load test store '\(testName)' at '\(storePath)': \(reason)"
    }
  }
}

extension NSPersistentContainer {
  /// Core Data store loading is not stable under extreme parallel test container creation.
  ///
  /// This lock exists because real-world suites can create many `NSPersistentContainer`
  /// instances concurrently in the same process while still using shared static helpers such as
  /// a single `NSManagedObjectModel` factory.
  ///
  /// That exact pattern showed up in `PersistentHistoryTrackingKit`'s tests:
  /// many Core Data-heavy test cases, one process, shared static test model/container helpers,
  /// unique SQLite store URLs, and still sporadic crashes or deadlocks during
  /// `loadPersistentStores`.
  ///
  /// Serialize the container creation/loading path for test containers to avoid those failures,
  /// while still allowing the tests themselves to execute in parallel after initialization.
  private static let testContainerCreationLock = NSLock()

  /// Creates an `NSPersistentContainer` backed by an isolated on-disk SQLite store for use in
  /// unit tests.
  ///
  /// This helper is intended as a **one-shot test container**:
  /// 1. It derives a store file name from `testName`, or from call-site `#fileID-#function`
  ///    when `testName` is omitted.
  /// 2. It deletes any pre-existing SQLite files at that path (`.sqlite`, `.sqlite-shm`,
  ///    `.sqlite-wal`) before loading the store, giving that call a fresh store state.
  ///
  /// Typical usage is one container per test method when relying on the default naming rule.
  /// If a single test needs multiple containers, pass distinct `testName` values so each call
  /// gets its own store path.
  ///
  /// This avoids the two most common pitfalls of test stores:
  /// - **`/dev/null` (shared in-memory)**: All tests sharing the same `/dev/null` URL read and
  ///   write the same in-memory store. Parallel test execution can cause data leakage and
  ///   deadlocks.
  /// - **Named in-memory stores**: SQLite's WAL journal and shared-memory sidecar files can
  ///   linger between runs when using a named in-memory store, leading to phantom data.
  ///
  /// It also guards against a separate issue: even with unique store URLs, creating many Core
  /// Data containers concurrently in one process can still crash or hang inside
  /// `loadPersistentStores`. `makeTest` serializes only the container creation/loading path to
  /// keep parallel test execution viable.
  ///
  /// This SQLite-backed approach is intentionally pragmatic for tests:
  /// - it avoids the shared-state hazards of `/dev/null` and similar in-memory approaches
  /// - it exercises a more realistic SQLite + WAL environment
  /// - in heavily parallel test suites, it is often more stable than shared in-memory setups
  ///
  /// **Typical usage:**
  /// ```swift
  /// @Test func createItem() async throws {
  ///     // testName defaults to #fileID-#function, which is usually enough for one container
  ///     // per test method.
  ///     let container = try NSPersistentContainer.makeTest(model: MyModel.objectModel)
  ///     let handler = DataHandler(container: container)
  ///     // … test body …
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - model: The `NSManagedObjectModel` describing your Core Data schema.
  ///   - testName: Optional explicit store name override. If omitted, a name is derived from
  ///     call-site `#fileID` and `#function`. Pass a distinct value when one test method needs
  ///     more than one container.
  ///   - fileID: Pass-through call-site file identity used when `testName` is omitted.
  ///   - function: Pass-through call-site function identity used when `testName` is omitted.
  ///   - subDirectory: The temporary sub-directory used to store the SQLite files.
  ///     Defaults to `"CoreDataEvolutionTestTemp"`.
  /// - Returns: A fully loaded `NSPersistentContainer` ready for use.
  /// - Throws: `CDTestContainerError` if the temporary store directory cannot be prepared,
  ///   stale store files cannot be removed, or Core Data fails to load the SQLite store.
  ///
  /// - Note: Store files are written to `URL.temporaryDirectory/<subDirectory>/`.
  ///   They are removed on the *next* call that resolves to the same store path, not immediately
  ///   after the test completes, so they can be inspected for debugging if needed.
  public static func makeTest(
    model: NSManagedObjectModel,
    testName: String = "",
    fileID: String = #fileID,
    function: String = #function,
    subDirectory: String = "CoreDataEvolutionTestTemp"
  ) throws -> NSPersistentContainer {
    try makeTest(
      model: model,
      testName: testName,
      fileID: fileID,
      function: function,
      subDirectory: subDirectory,
      loadStoresUsing: defaultTestStoreLoader
    )
  }

  static func makeTest(
    model: NSManagedObjectModel,
    testName: String = "",
    fileID: String = #fileID,
    function: String = #function,
    subDirectory: String = "CoreDataEvolutionTestTemp",
    loadStoresUsing loadStores: (NSPersistentContainer) -> Error?
  ) throws -> NSPersistentContainer {
    testContainerCreationLock.lock()
    defer { testContainerCreationLock.unlock() }

    let resolvedTestName = testName.isEmpty ? "\(fileID)-\(function)" : testName
    let testDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(
      subDirectory)

    if !FileManager.default.fileExists(atPath: testDirectory.path) {
      do {
        try FileManager.default.createDirectory(
          at: testDirectory,
          withIntermediateDirectories: true
        )
      } catch {
        throw CDTestContainerError.failedToCreateStoreDirectory(
          path: testDirectory.path,
          reason: String(describing: error)
        )
      }
    }

    let sanitizedStoreName = sanitizeStoreFileName(resolvedTestName)
    let storeURL = testDirectory.appendingPathComponent("\(sanitizedStoreName).sqlite")

    // Remove stale SQLite files (main + WAL journal sidecar files) before loading.
    for suffix in ["", "-shm", "-wal"] {
      let path = storeURL.path + suffix
      if FileManager.default.fileExists(atPath: path) {
        do {
          try FileManager.default.removeItem(atPath: path)
        } catch {
          throw CDTestContainerError.failedToRemoveStaleStoreFile(
            path: path,
            reason: String(describing: error)
          )
        }
      }
    }

    let container = NSPersistentContainer(name: sanitizedStoreName, managedObjectModel: model)

    let description = NSPersistentStoreDescription(url: storeURL)
    description.shouldAddStoreAsynchronously = false
    container.persistentStoreDescriptions = [description]

    let loadFailure = loadStores(container)
    if let loadFailure {
      throw CDTestContainerError.failedToLoadPersistentStore(
        testName: resolvedTestName,
        storePath: storeURL.path,
        reason: String(describing: loadFailure)
      )
    }

    return container
  }

  /// Builds a test container from macro-emitted runtime schema instead of `.xcdatamodeld`.
  ///
  /// This is intended for test/debug workflows where the participating `@PersistentModel` types
  /// are already known in code and a separate model file would add unnecessary friction.
  ///
  /// - Parameters:
  ///   - modelTypes: The participating model types. The list must include every entity referenced
  ///     by relationships in the runtime-built schema.
  ///   - testName: Optional explicit store name override. If omitted, a name is derived from the
  ///     call site.
  ///   - fileID: Pass-through call-site file identity used when `testName` is omitted.
  ///   - function: Pass-through call-site function identity used when `testName` is omitted.
  ///   - subDirectory: Temporary subdirectory used for the SQLite files.
  /// - Returns: A fully loaded `NSPersistentContainer`.
  /// - Throws: `CDRuntimeModelBuilderError` if runtime model assembly fails, or
  ///   `CDTestContainerError` if the SQLite-backed test store cannot be prepared or loaded.
  public static func makeRuntimeTest(
    modelTypes: [any CDRuntimeSchemaProviding.Type],
    testName: String = "",
    fileID: String = #fileID,
    function: String = #function,
    subDirectory: String = "CoreDataEvolutionTestTemp"
  ) throws -> NSPersistentContainer {
    let model = try NSManagedObjectModel.makeRuntimeModel(modelTypes)
    return try makeTest(
      model: model,
      testName: testName,
      fileID: fileID,
      function: function,
      subDirectory: subDirectory
    )
  }

  /// Variadic convenience overload for compact runtime-model test setup.
  public static func makeRuntimeTest(
    modelTypes: any CDRuntimeSchemaProviding.Type...,
    testName: String = "",
    fileID: String = #fileID,
    function: String = #function,
    subDirectory: String = "CoreDataEvolutionTestTemp"
  ) throws -> NSPersistentContainer {
    try makeRuntimeTest(
      modelTypes: modelTypes,
      testName: testName,
      fileID: fileID,
      function: function,
      subDirectory: subDirectory
    )
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

  private static func defaultTestStoreLoader(_ container: NSPersistentContainer) -> Error? {
    var loadFailure: Error?
    container.loadPersistentStores { _, error in
      loadFailure = error
    }
    return loadFailure
  }
}
