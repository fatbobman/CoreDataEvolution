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

/// Runtime-schema entry point emitted by `@PersistentModel`.
/// The upcoming test/debug model builder consumes only this static metadata and does not perform
/// reflection over Swift properties.
public protocol CDRuntimeSchemaProviding: NSManagedObject {
  static var __cdRuntimeEntitySchema: CDRuntimeEntitySchema { get }
}

/// Lightweight collection helpers for test/debug runtime schema assembly.
public enum CDRuntimeSchemaCollection {
  public static func entitySchemas(
    _ types: [any CDRuntimeSchemaProviding.Type]
  ) -> [CDRuntimeEntitySchema] {
    types.map { $0.__cdRuntimeEntitySchema }
  }

  /// Variadic convenience for ad-hoc test/debug setup where the entity list is known inline.
  public static func entitySchemas(
    _ types: any CDRuntimeSchemaProviding.Type...
  ) -> [CDRuntimeEntitySchema] {
    entitySchemas(types)
  }
}
