//
//  ------------------------------------------------
//  Original project: CoreDataEvolution
//  Created on 2026/3/6 by Fatbobman(东坡肘子)
//  X: @fatbobman
//  Mastodon: @fatbobman@mastodon.social
//  GitHub: @fatbobman
//  Blog: https://fatbobman.com
//  ------------------------------------------------
//  Copyright © 2024-present Fatbobman. All rights reserved.

import CoreData
import Foundation

/// Test/debug-oriented runtime stack that mirrors the package's existing stack helpers.
/// It keeps the participating model types, emitted runtime schema, assembled model, and
/// SQLite-backed container together so tests can hand the container to actors without repeating
/// setup code.
public final class CDRuntimeModelStack {
  public let modelTypes: [any CDRuntimeSchemaProviding.Type]
  public let schemas: [CDRuntimeEntitySchema]
  public let model: NSManagedObjectModel
  public let container: NSPersistentContainer

  @MainActor public var viewContext: NSManagedObjectContext {
    container.viewContext
  }

  public init(
    modelTypes: [any CDRuntimeSchemaProviding.Type],
    testName: String = "",
    fileID: String = #fileID,
    function: String = #function,
    subDirectory: String = "CoreDataEvolutionTestTemp",
    automaticallyMergesChangesFromParent: Bool = true
  ) throws {
    self.modelTypes = modelTypes
    schemas = CDRuntimeSchemaCollection.entitySchemas(modelTypes)
    model = try NSManagedObjectModel.makeRuntimeModel(modelTypes)
    container = NSPersistentContainer.makeTest(
      model: model,
      testName: testName,
      fileID: fileID,
      function: function,
      subDirectory: subDirectory
    )
    container.viewContext.automaticallyMergesChangesFromParent =
      automaticallyMergesChangesFromParent
  }

  /// Variadic convenience overload for the common "list the participating types inline" setup.
  public convenience init(
    modelTypes: any CDRuntimeSchemaProviding.Type...,
    testName: String = "",
    fileID: String = #fileID,
    function: String = #function,
    subDirectory: String = "CoreDataEvolutionTestTemp",
    automaticallyMergesChangesFromParent: Bool = true
  ) throws {
    try self.init(
      modelTypes: modelTypes,
      testName: testName,
      fileID: fileID,
      function: function,
      subDirectory: subDirectory,
      automaticallyMergesChangesFromParent: automaticallyMergesChangesFromParent
    )
  }

  /// Mirrors `NSPersistentContainer.newBackgroundContext()` so tests can keep stack-based setup
  /// while still creating ad-hoc verification contexts.
  public func newBackgroundContext() -> NSManagedObjectContext {
    container.newBackgroundContext()
  }

  /// Pass-through for `performBackgroundTask` to avoid reaching through the container in tests.
  public func performBackgroundTask(_ block: @escaping @Sendable (NSManagedObjectContext) -> Void) {
    container.performBackgroundTask(block)
  }
}
