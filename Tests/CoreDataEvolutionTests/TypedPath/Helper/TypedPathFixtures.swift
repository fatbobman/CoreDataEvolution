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

final class PathOwnerModel: NSObject, CoreDataKeys, CoreDataPathDSLProviding {
  enum Keys: String {
    case identifier = "owner_uuid"
    case status = "owner_status"
  }

  enum Paths {
    static let identifier = CDPath<PathOwnerModel, UUID>(
      swiftPath: ["identifier"],
      persistentPath: ["owner_uuid"]
    )

    static let status = CDPath<PathOwnerModel, PathItemStatus?>(
      swiftPath: ["status"],
      persistentPath: ["owner_status"],
      storageMethod: .raw
    )
  }

  static let __cdFieldTable: [String: CDFieldMeta] = [
    "identifier": .init(
      kind: .attribute,
      swiftPath: ["identifier"],
      persistentPath: ["owner_uuid"],
      storageMethod: .default,
      supportsStoreSort: true
    ),
    "status": .init(
      kind: .attribute,
      swiftPath: ["status"],
      persistentPath: ["owner_status"],
      storageMethod: .raw,
      supportsStoreSort: true
    ),
  ]

  struct PathRoot: Sendable {
    var identifier: CDPath<PathOwnerModel, UUID> {
      Paths.identifier
    }

    var status: CDPath<PathOwnerModel, PathItemStatus?> {
      Paths.status
    }
  }

  static var path: PathRoot {
    .init()
  }
}

final class PathProjectModel: NSObject, CoreDataKeys, CoreDataPathDSLProviding {
  enum Keys: String {
    case title = "project_title"
  }

  enum Paths {
    static let title = CDPath<PathProjectModel, String?>(
      swiftPath: ["title"],
      persistentPath: ["project_title"]
    )

    static let owner = CDToOneRelationPath<PathProjectModel, PathOwnerModel>(
      swiftPath: ["owner"],
      persistentPath: ["primary_owner"]
    )
  }

  static let __cdFieldTable: [String: CDFieldMeta] = [
    "title": .init(
      kind: .attribute,
      swiftPath: ["title"],
      persistentPath: ["project_title"],
      storageMethod: .default,
      supportsStoreSort: true
    ),
    "owner": .init(
      kind: .relationship,
      swiftPath: ["owner"],
      persistentPath: ["primary_owner"],
      storageMethod: .default,
      supportsStoreSort: false
    ),
    "owner.identifier": .init(
      kind: .relationship,
      swiftPath: ["owner", "identifier"],
      persistentPath: ["primary_owner", "owner_uuid"],
      storageMethod: .default,
      supportsStoreSort: true
    ),
    "owner.status": .init(
      kind: .relationship,
      swiftPath: ["owner", "status"],
      persistentPath: ["primary_owner", "owner_status"],
      storageMethod: .raw,
      supportsStoreSort: true
    ),
  ]

  struct PathRoot: Sendable {
    var title: CDPath<PathProjectModel, String?> {
      Paths.title
    }

    var owner: CDToOneRelationPath<PathProjectModel, PathOwnerModel> {
      Paths.owner
    }
  }

  static var path: PathRoot {
    .init()
  }
}

final class PathTaskModel: NSObject, CoreDataKeys, CoreDataPathDSLProviding {
  enum Keys: String {
    case title = "task_title"
  }

  enum Paths {
    static let title = CDPath<PathTaskModel, String?>(
      swiftPath: ["title"],
      persistentPath: ["task_title"]
    )

    static let project = CDToOneRelationPath<PathTaskModel, PathProjectModel>(
      swiftPath: ["project"],
      persistentPath: ["current_project"]
    )
  }

  static let __cdFieldTable: [String: CDFieldMeta] = [
    "title": .init(
      kind: .attribute,
      swiftPath: ["title"],
      persistentPath: ["task_title"],
      storageMethod: .default,
      supportsStoreSort: true
    ),
    "project": .init(
      kind: .relationship,
      swiftPath: ["project"],
      persistentPath: ["current_project"],
      storageMethod: .default,
      supportsStoreSort: false
    ),
    "project.title": .init(
      kind: .relationship,
      swiftPath: ["project", "title"],
      persistentPath: ["current_project", "project_title"],
      storageMethod: .default,
      supportsStoreSort: true
    ),
  ]

  struct PathRoot: Sendable {
    var title: CDPath<PathTaskModel, String?> {
      Paths.title
    }

    var project: CDToOneRelationPath<PathTaskModel, PathProjectModel> {
      Paths.project
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
