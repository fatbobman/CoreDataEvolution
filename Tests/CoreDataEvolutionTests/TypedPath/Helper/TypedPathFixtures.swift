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

@Composition
struct PathLocationComposition {
  @CompositionField(persistentName: "lat")
  var x: Double

  @CompositionField(persistentName: "lng")
  var y: Double?
}

enum PathItemStatus: String, Sendable {
  case active
  case archived
}

final class PathTagModel: NSObject, CoreDataKeys, CoreDataPathDSLProviding {
  enum Keys: String {
    case name = "tag_name"
    case score = "score"
  }

  enum Paths {
    static let name = CDPath<PathTagModel, String?>(
      swiftPath: ["name"],
      persistentPath: ["tag_name"]
    )

    static let score = CDPath<PathTagModel, Int>(
      swiftPath: ["score"],
      persistentPath: ["score"]
    )
  }

  static let __cdFieldTable: [String: CDFieldMeta] = [
    "name": .init(
      kind: .attribute,
      swiftPath: ["name"],
      persistentPath: ["tag_name"],
      storageMethod: .default,
      supportsStoreSort: true
    ),
    "score": .init(
      kind: .attribute,
      swiftPath: ["score"],
      persistentPath: ["score"],
      storageMethod: .default,
      supportsStoreSort: true
    ),
  ]

  struct PathRoot: Sendable {
    var name: CDPath<PathTagModel, String?> {
      Paths.name
    }

    var score: CDPath<PathTagModel, Int> {
      Paths.score
    }
  }

  static var path: PathRoot {
    .init()
  }
}

final class PathItemModel: NSObject, CoreDataKeys, CoreDataPathDSLProviding {
  enum Keys: String {
    case date = "timestamp"
    case title = "title"
    case status = "status_raw"
  }

  enum Paths {
    static let date = CDPath<PathItemModel, Date?>(
      swiftPath: ["date"],
      persistentPath: ["timestamp"]
    )

    static let title = CDPath<PathItemModel, String?>(
      swiftPath: ["title"],
      persistentPath: ["title"]
    )

    static let status = CDPath<PathItemModel, PathItemStatus?>(
      swiftPath: ["status"],
      persistentPath: ["status_raw"],
      storageMethod: .raw
    )

    static let metadata = CDPath<PathItemModel, Data?>(
      swiftPath: ["metadata"],
      persistentPath: ["metadata_blob"],
      storageMethod: .codable
    )

    static let location = CDCompositionPath<
      PathItemModel, PathLocationComposition?, PathLocationComposition
    >(
      root: CDPath<PathItemModel, PathLocationComposition?>(
        swiftPath: ["location"],
        persistentPath: ["location"],
        storageMethod: .composition
      )
    )

    enum category {
      static let name = CDPath<PathItemModel, String?>(
        swiftPath: ["category", "name"],
        persistentPath: ["category", "name"]
      )
    }

    static let tags = CDToManyRelationPath<PathItemModel, PathTagModel>(
      swiftPath: ["tags"],
      persistentPath: ["tags"]
    )
  }

  static let __cdFieldTable: [String: CDFieldMeta] = [
    "date": .init(
      kind: .attribute,
      swiftPath: ["date"],
      persistentPath: ["timestamp"],
      storageMethod: .default,
      supportsStoreSort: true
    ),
    "title": .init(
      kind: .attribute,
      swiftPath: ["title"],
      persistentPath: ["title"],
      storageMethod: .default,
      supportsStoreSort: true
    ),
    "status": .init(
      kind: .attribute,
      swiftPath: ["status"],
      persistentPath: ["status_raw"],
      storageMethod: .raw,
      supportsStoreSort: true
    ),
    "metadata": .init(
      kind: .attribute,
      swiftPath: ["metadata"],
      persistentPath: ["metadata_blob"],
      storageMethod: .codable,
      supportsStoreSort: false
    ),
    "location": .init(
      kind: .composition,
      swiftPath: ["location"],
      persistentPath: ["location"],
      storageMethod: .composition,
      supportsStoreSort: false
    ),
    "location.x": .init(
      kind: .attribute,
      swiftPath: ["location", "x"],
      persistentPath: ["location", "lat"],
      storageMethod: .default,
      supportsStoreSort: true
    ),
    "location.y": .init(
      kind: .attribute,
      swiftPath: ["location", "y"],
      persistentPath: ["location", "lng"],
      storageMethod: .default,
      supportsStoreSort: true
    ),
    "category.name": .init(
      kind: .relationship,
      swiftPath: ["category", "name"],
      persistentPath: ["category", "name"],
      storageMethod: .default,
      supportsStoreSort: true
    ),
    "tags.name": .init(
      kind: .relationship,
      swiftPath: ["tags", "name"],
      persistentPath: ["tags", "tag_name"],
      storageMethod: .default,
      supportsStoreSort: false,
      isToManyRelationship: true
    ),
    "tags.score": .init(
      kind: .relationship,
      swiftPath: ["tags", "score"],
      persistentPath: ["tags", "score"],
      storageMethod: .default,
      supportsStoreSort: false,
      isToManyRelationship: true
    ),
  ]

  struct PathRoot: Sendable {
    var date: CDPath<PathItemModel, Date?> {
      Paths.date
    }

    var title: CDPath<PathItemModel, String?> {
      Paths.title
    }

    var status: CDPath<PathItemModel, PathItemStatus?> {
      Paths.status
    }

    var metadata: CDPath<PathItemModel, Data?> {
      Paths.metadata
    }

    var location:
      CDCompositionPath<PathItemModel, PathLocationComposition?, PathLocationComposition>
    {
      Paths.location
    }

    var category: CategoryPath {
      .init()
    }

    var tags: CDToManyRelationPath<PathItemModel, PathTagModel> {
      Paths.tags
    }
  }

  struct CategoryPath: Sendable {
    var name: CDPath<PathItemModel, String?> {
      Paths.category.name
    }
  }

  static var path: PathRoot {
    .init()
  }
}
