//
//  ------------------------------------------------
//  Original project: CoreDataEvolution
//  Created on 2026/3/5 by Fatbobman(东坡肘子)
//  X: @fatbobman
//  Mastodon: @fatbobman@mastodon.social
//  GitHub: @fatbobman
//  Blog: https://fatbobman.com
//  ------------------------------------------------
//  Copyright © 2024-present Fatbobman. All rights reserved.

import Foundation

/// Internal macro-expansion validation helpers.
///
/// These APIs are public only because macro-expanded user code lives in a client module
/// and must reference symbols from `CoreDataEvolution`.
public enum _CDAttributeMacroValidation {
  @inlinable
  public static func requireRawRepresentable<T: RawRepresentable>(_: T.Type) {}

  @inlinable
  public static func requireCodable<T: Codable>(_: T.Type) {}

  @inlinable
  public static func requireTransformer<T: ValueTransformer>(_: T.Type) {}

  @inlinable
  public static func requireComposition<T: CDCompositionValueCodable & CDCompositionPathProviding>(
    _: T.Type
  ) {}

  @inlinable
  public static func requireNonRelationship<T>(_: T.Type) {}

  @available(
    *,
    unavailable,
    message:
      "@Attribute cannot be applied to relationship properties. Remove @Attribute from this property."
  )
  public static func requireNonRelationship<T: NSManagedObject>(_: T.Type) {}

  @available(
    *,
    unavailable,
    message:
      "@Attribute cannot be applied to to-one relationship properties (`T?` where `T: NSManagedObject`)."
  )
  public static func requireNonRelationship<T: NSManagedObject>(_: T?.Type) {}

  @available(
    *,
    unavailable,
    message:
      "@Attribute cannot be applied to to-many relationship properties (`Set<T>` where `T: NSManagedObject`)."
  )
  public static func requireNonRelationship<T: NSManagedObject>(_: Set<T>.Type) {}

  @available(
    *,
    unavailable,
    message:
      "@Attribute cannot be applied to ordered to-many relationship properties (`[T]` where `T: NSManagedObject`)."
  )
  public static func requireNonRelationship<T: NSManagedObject>(_: [T].Type) {}
}
