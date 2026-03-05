import Foundation
import Testing

@testable import KeysPathsLookupPOC

struct LocationComposition: CDCompositionPathProviding {
  // Simulated generated output by @Composition macro.
  static let __cdCompositionFieldTable: [String: CDCompositionFieldMeta] = [
    "x": .init(
      swiftPath: ["x"],
      persistentPath: ["x"]
    ),
    "y": .init(
      swiftPath: ["y"],
      persistentPath: ["y"]
    ),
  ]
}

final class TagModel: NSObject, CoreDataKeys, CoreDataPathDSLProviding {
  enum Keys: String {
    case name = "tag_name"
    case score = "score"
  }

  enum Paths {
    static let name = CDPath<TagModel, String?>(
      swiftPath: ["name"],
      persistentPath: ["tag_name"]
    )

    static let score = CDPath<TagModel, Int>(
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
    var name: CDPath<TagModel, String?> {
      Paths.name
    }

    var score: CDPath<TagModel, Int> {
      Paths.score
    }
  }

  static var path: PathRoot {
    .init()
  }
}

final class ItemModel: NSObject, CoreDataKeys, CoreDataPathDSLProviding {
  enum Keys: String {
    case date = "timestamp"
    case title = "title"
    case status = "status_raw"
  }

  enum Paths {
    static let date = CDPath<ItemModel, Date?>(
      swiftPath: ["date"],
      persistentPath: ["timestamp"]
    )

    static let title = CDPath<ItemModel, String?>(
      swiftPath: ["title"],
      persistentPath: ["title"]
    )

    static let status = CDPath<ItemModel, String?>(
      swiftPath: ["status"],
      persistentPath: ["status_raw"],
      storageMethod: .raw
    )

    static let metadata = CDPath<ItemModel, Data?>(
      swiftPath: ["metadata"],
      persistentPath: ["metadata_blob"],
      storageMethod: .codable
    )

    enum magnitude {
      static let root = CDPath<ItemModel, [String: Any]?>(
        swiftPath: ["magnitude"],
        persistentPath: ["magnitude"],
        storageMethod: .composition
      )

      static let richter = CDPath<ItemModel, Double>(
        swiftPath: ["magnitude", "richter"],
        persistentPath: ["magnitude", "richter"]
      )
    }

    enum category {
      static let name = CDPath<ItemModel, String?>(
        swiftPath: ["category", "name"],
        persistentPath: ["category", "name"]
      )
    }

    static let tags = CDToManyRelationPath<ItemModel, TagModel>(
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
    "magnitude": .init(
      kind: .composition,
      swiftPath: ["magnitude"],
      persistentPath: ["magnitude"],
      storageMethod: .composition,
      supportsStoreSort: false
    ),
    "magnitude.richter": .init(
      kind: .attribute,
      swiftPath: ["magnitude", "richter"],
      persistentPath: ["magnitude", "richter"],
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
    var date: CDPath<ItemModel, Date?> {
      Paths.date
    }

    var title: CDPath<ItemModel, String?> {
      Paths.title
    }

    var status: CDPath<ItemModel, String?> {
      Paths.status
    }

    var metadata: CDPath<ItemModel, Data?> {
      Paths.metadata
    }

    var magnitude: MagnitudePath {
      .init()
    }

    var category: CategoryPath {
      .init()
    }

    var tags: CDToManyRelationPath<ItemModel, TagModel> {
      Paths.tags
    }
  }

  struct MagnitudePath: Sendable {
    var root: CDPath<ItemModel, [String: Any]?> {
      Paths.magnitude.root
    }

    var richter: CDPath<ItemModel, Double> {
      Paths.magnitude.richter
    }
  }

  struct CategoryPath: Sendable {
    var name: CDPath<ItemModel, String?> {
      Paths.category.name
    }
  }

  static var path: PathRoot {
    .init()
  }
}

@Test func keySortUsesPersistentName() throws {
  let descriptor = NSSortDescriptor(ItemModel.self, key: .date, ascending: true)
  #expect(descriptor.key == "timestamp")
  #expect(descriptor.ascending)
}

@Test func compositionLeafPathSupportsStoreSort() throws {
  let descriptor = try NSSortDescriptor(
    ItemModel.self,
    path: ItemModel.path.magnitude.richter,
    order: .desc
  )
  #expect(descriptor.key == "magnitude.richter")
  #expect(descriptor.ascending == false)
}

@Test func renamedFieldResolvesForFuturePredicateMapping() throws {
  let persistent = ItemModel.__cdPersistentPath(forSwiftPath: "date")
  #expect(persistent == "timestamp")
}

@Test func relationshipSubpathSupportsStoreSort() throws {
  let descriptor = try NSSortDescriptor(
    ItemModel.self,
    path: ItemModel.path.category.name,
    order: .asc
  )
  #expect(descriptor.key == "category.name")
}

@Test func unregisteredPathThrows() throws {
  let unknownPath = CDPath<ItemModel, Int>(
    swiftPath: ["unknown"],
    persistentPath: ["unknown"]
  )

  #expect(throws: CDSortDescriptorError.pathNotRegistered("unknown")) {
    _ = try NSSortDescriptor(ItemModel.self, path: unknownPath, order: .asc)
  }
}

@Test func pathMismatchThrows() throws {
  let mismatchedPath = CDPath<ItemModel, String?>(
    swiftPath: ["title"],
    persistentPath: ["unexpected_name"]
  )
  #expect(
    throws: CDSortDescriptorError.pathMismatch(expected: "title", got: "unexpected_name")
  ) {
    _ = try NSSortDescriptor(ItemModel.self, path: mismatchedPath, order: .asc)
  }
}

@Test func storeModeRejectsNonStoreCollation() throws {
  #expect(throws: CDSortDescriptorError.collationRequiresInMemory(.localized)) {
    _ = try NSSortDescriptor(
      ItemModel.self,
      path: ItemModel.path.title,
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
      ItemModel.self,
      path: ItemModel.path.metadata,
      order: .asc,
      mode: .storeCompatible
    )
  }
}

@Test func inMemoryModeAllowsLocalizedCollation() throws {
  let descriptor = try NSSortDescriptor(
    ItemModel.self,
    path: ItemModel.path.title,
    order: .asc,
    collation: .localizedStandard,
    mode: .inMemory
  )
  #expect(descriptor.key == "title")
}

@Test func pathDslSupportsNormalAndCompositionForms() throws {
  #expect(ItemModel.path.title.swiftPathKey == "title")
  #expect(ItemModel.path.title.raw == "title")
  #expect(ItemModel.path.magnitude.richter.swiftPathKey == "magnitude.richter")
  #expect(ItemModel.path.magnitude.richter.raw == "magnitude.richter")
  #expect(ItemModel.path.tags.any.name.persistentPathKey == "tags.tag_name")
  #expect(ItemModel.path.tags.any.name.raw == "tags.tag_name")
}

@Test func toManyAnyBuildsPredicate() throws {
  let predicate = ItemModel.path.tags.any.name.equals("Swift")
  #expect(predicate.predicateFormat.contains("ANY tags.tag_name =="))
}

@Test func toManyAllBuildsPredicate() throws {
  let predicate = ItemModel.path.tags.all.score.greaterThan(80)
  #expect(predicate.predicateFormat.contains("NOT ANY tags.score <="))
}

@Test func toManyNoneBuildsPredicate() throws {
  let predicate = ItemModel.path.tags.none.name.contains("legacy")
  #expect(predicate.predicateFormat.contains("NOT ANY tags.tag_name CONTAINS"))
}

@Test func toManyNoneMatchesExplicitNotAny() throws {
  let fromDsl = ItemModel.path.tags.none.name.equals("Swift")
  let explicit = NSCompoundPredicate(
    notPredicateWithSubpredicate: NSPredicate(
      format: "ANY %K == %@",
      argumentArray: ["tags.tag_name", "Swift"]
    )
  )
  #expect(fromDsl.predicateFormat == explicit.predicateFormat)
}

@Test func toManyAndNormalFieldsCanComposePredicate() throws {
  let predicate = NSCompoundPredicate(
    andPredicateWithSubpredicates: [
      ItemModel.path.tags.any.name.equals("Swift"),
      ItemModel.path.title.contains("Core Data"),
    ]
  )
  #expect(predicate.predicateFormat.contains("ANY tags.tag_name =="))
  #expect(predicate.predicateFormat.contains("title CONTAINS"))
}

@Test func compositionTypeProvidesStaticFieldTable() throws {
  #expect(LocationComposition.__cdCompositionFieldTable["x"]?.swiftPath == ["x"])
  #expect(LocationComposition.__cdCompositionFieldTable["y"]?.persistentPath == ["y"])
}

@Test func mainModelCanBuildCompositionEntriesWithoutReflection() throws {
  let entries = CDCompositionTableBuilder.makeModelFieldEntries(
    modelSwiftPathPrefix: ["location"],
    modelPersistentPathPrefix: ["location"],
    composition: LocationComposition.self
  )
  #expect(entries["location.x"]?.persistentPath == ["location", "x"])
  #expect(entries["location.y"]?.swiftPath == ["location", "y"])
}
