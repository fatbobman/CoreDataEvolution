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

import CoreDataEvolution
import Foundation
import Testing

@Suite("TypedPath Sort Tests")
struct TypedPathSortTests {
  @Test func keySortUsesPersistentName() throws {
    let descriptor = NSSortDescriptor(PathItemModel.self, key: .date, ascending: true)
    #expect(descriptor.key == "timestamp")
    #expect(descriptor.ascending)
  }

  @Test func compositionLeafPathSupportsStoreSort() throws {
    let descriptor = try NSSortDescriptor(
      PathItemModel.self,
      path: PathItemModel.path.location.x,
      order: .desc
    )
    #expect(descriptor.key == "location.lat")
    #expect(descriptor.ascending == false)
  }

  @Test func renamedFieldResolvesForFuturePredicateMapping() throws {
    let persistent = PathItemModel.__cdPersistentPath(forSwiftPath: "date")
    #expect(persistent == "timestamp")
  }

  @Test func relationshipSubpathSupportsStoreSort() throws {
    let descriptor = try NSSortDescriptor(
      PathItemModel.self,
      path: PathItemModel.path.category.name,
      order: .asc
    )
    #expect(descriptor.key == "category.name")
  }

  @Test func unregisteredPathThrows() throws {
    let unknownPath = CDPath<PathItemModel, Int>(
      swiftPath: ["unknown"],
      persistentPath: ["unknown"]
    )

    #expect(throws: CDSortDescriptorError.pathNotRegistered("unknown")) {
      _ = try NSSortDescriptor(PathItemModel.self, path: unknownPath, order: .asc)
    }
  }

  @Test func pathMismatchThrows() throws {
    let mismatchedPath = CDPath<PathItemModel, String?>(
      swiftPath: ["title"],
      persistentPath: ["unexpected_name"]
    )
    #expect(
      throws: CDSortDescriptorError.pathMismatch(expected: "title", got: "unexpected_name")
    ) {
      _ = try NSSortDescriptor(PathItemModel.self, path: mismatchedPath, order: .asc)
    }
  }

  @Test func storeModeRejectsNonStoreCollation() throws {
    #expect(throws: CDSortDescriptorError.collationRequiresInMemory(.localized)) {
      _ = try NSSortDescriptor(
        PathItemModel.self,
        path: PathItemModel.path.title,
        order: .asc,
        collation: .localized,
        mode: .storeCompatible
      )
    }
  }

  @Test func storeModeRejectsNonSortableStorageMethod() throws {
    #expect(
      throws: CDSortDescriptorError.pathNotStoreSortable(
        "metadata",
        storageMethod: .codable
      )
    ) {
      _ = try NSSortDescriptor(
        PathItemModel.self,
        path: PathItemModel.path.metadata,
        order: .asc,
        mode: .storeCompatible
      )
    }
  }

  @Test func inMemoryModeAllowsLocalizedCollation() throws {
    let descriptor = try NSSortDescriptor(
      PathItemModel.self,
      path: PathItemModel.path.title,
      order: .asc,
      collation: .localizedStandard,
      mode: .inMemory
    )
    #expect(descriptor.key == "title")
  }
}
