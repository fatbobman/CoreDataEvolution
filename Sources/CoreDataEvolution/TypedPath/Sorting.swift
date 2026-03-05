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

public enum SortOrder: Equatable, Sendable {
  case asc
  case desc
}

public enum SortCollation: Equatable, Sendable {
  case storeDefault
  case localized
  case localizedStandard
}

public enum SortExecutionMode: Equatable, Sendable {
  case storeCompatible
  case inMemory
}

/// Errors surfaced by typed sort descriptor construction.
public enum CDSortDescriptorError: Error, Equatable {
  case pathNotRegistered(String)
  case pathMismatch(expected: String, got: String)
  case toManyRelationshipNotSupportedForSort(String)
  case collationRequiresInMemory(SortCollation)
  case pathNotStoreSortable(String, storageMethod: StorageMethod)
}

extension NSSortDescriptor {
  public convenience init<Object: CoreDataKeys>(
    _ type: Object.Type,
    key: Object.Keys,
    ascending: Bool
  ) {
    self.init(key: key.rawValue, ascending: ascending)
  }

  public convenience init<Object: CoreDataPathTable, Value>(
    _ type: Object.Type,
    path: CDPath<Object, Value>,
    order: SortOrder,
    collation: SortCollation = .storeDefault,
    mode: SortExecutionMode = .storeCompatible
  ) throws {
    let swiftPathKey = path.swiftPathKey
    guard let meta = Object.__cdMeta(forSwiftPath: swiftPathKey) else {
      throw CDSortDescriptorError.pathNotRegistered(swiftPathKey)
    }

    // Ensure the path object and table registration do not drift.
    let expected = meta.persistentPath.joined(separator: ".")
    let got = path.persistentPathKey
    guard expected == got else {
      throw CDSortDescriptorError.pathMismatch(expected: expected, got: got)
    }
    if meta.isToManyRelationship {
      throw CDSortDescriptorError.toManyRelationshipNotSupportedForSort(swiftPathKey)
    }

    if mode == .storeCompatible {
      if collation != .storeDefault {
        throw CDSortDescriptorError.collationRequiresInMemory(collation)
      }
      if meta.supportsStoreSort == false {
        throw CDSortDescriptorError.pathNotStoreSortable(
          swiftPathKey,
          storageMethod: meta.storageMethod
        )
      }
      self.init(key: expected, ascending: order == .asc)
      return
    }

    let ascending = order == .asc
    switch collation {
    case .storeDefault:
      self.init(key: expected, ascending: ascending)
    case .localized:
      self.init(key: expected, ascending: ascending) { lhs, rhs in
        let left = String(describing: lhs)
        let right = String(describing: rhs)
        return left.localizedCompare(right)
      }
    case .localizedStandard:
      self.init(key: expected, ascending: ascending) { lhs, rhs in
        let left = String(describing: lhs)
        let right = String(describing: rhs)
        return left.localizedStandardCompare(right)
      }
    }
  }
}
