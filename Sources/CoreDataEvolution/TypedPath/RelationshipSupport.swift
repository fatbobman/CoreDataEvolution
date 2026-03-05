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

import CoreData
import Foundation

/// Marker protocol used by model macro relationship type inference.
public protocol PersistentEntity: NSManagedObject, CoreDataKeys, CoreDataPathDSLProviding {}

/// Entry path for to-one relationships, e.g. `Model.path.category.name`.
@dynamicMemberLookup
public struct CDToOneRelationPath<
  Root: CoreDataPathTable,
  Target: CoreDataPathDSLProviding
>: @unchecked Sendable {
  public let swiftPath: [String]
  public let persistentPath: [String]

  public init(swiftPath: [String], persistentPath: [String]) {
    self.swiftPath = swiftPath
    self.persistentPath = persistentPath
  }

  public subscript<Value>(
    dynamicMember keyPath: KeyPath<Target.PathRoot, CDPath<Target, Value>>
  ) -> CDPath<Root, Value> {
    let targetPath = Target.path[keyPath: keyPath]
    return CDPath<Root, Value>(
      swiftPath: swiftPath + targetPath.swiftPath,
      persistentPath: persistentPath + targetPath.persistentPath,
      storageMethod: targetPath.storageMethod
    )
  }
}

/// Utility used by the model macro field-table generation step.
public enum CDRelationshipTableBuilder {
  public static func makeToOneFieldEntries<
    Target: CoreDataPathTable
  >(
    modelSwiftPathPrefix: [String],
    modelPersistentPathPrefix: [String],
    target: Target.Type
  ) -> [String: CDFieldMeta] {
    makeFieldEntries(
      modelSwiftPathPrefix: modelSwiftPathPrefix,
      modelPersistentPathPrefix: modelPersistentPathPrefix,
      target: target,
      isToMany: false
    )
  }

  public static func makeToManyFieldEntries<
    Target: CoreDataPathTable
  >(
    modelSwiftPathPrefix: [String],
    modelPersistentPathPrefix: [String],
    target: Target.Type
  ) -> [String: CDFieldMeta] {
    makeFieldEntries(
      modelSwiftPathPrefix: modelSwiftPathPrefix,
      modelPersistentPathPrefix: modelPersistentPathPrefix,
      target: target,
      isToMany: true
    )
  }

  private static func makeFieldEntries<
    Target: CoreDataPathTable
  >(
    modelSwiftPathPrefix: [String],
    modelPersistentPathPrefix: [String],
    target: Target.Type,
    isToMany: Bool
  ) -> [String: CDFieldMeta] {
    var result: [String: CDFieldMeta] = [:]
    for (_, leaf) in target.__cdRelationshipProjectionTable {
      // Prevent recursive expansion across relationship cycles (A -> B -> A).
      // Relationship subpaths should project target value/composition leaves only.
      if leaf.kind == .relationship {
        continue
      }
      let swiftPath = modelSwiftPathPrefix + leaf.swiftPath
      let persistentPath = modelPersistentPathPrefix + leaf.persistentPath
      let key = swiftPath.joined(separator: ".")
      result[key] = CDFieldMeta(
        kind: .relationship,
        swiftPath: swiftPath,
        persistentPath: persistentPath,
        storageMethod: leaf.storageMethod,
        supportsStoreSort: isToMany ? false : leaf.supportsStoreSort,
        isToManyRelationship: isToMany
      )
    }
    return result
  }
}
