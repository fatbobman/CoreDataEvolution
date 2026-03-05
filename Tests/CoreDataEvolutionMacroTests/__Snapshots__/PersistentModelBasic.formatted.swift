import CoreData
import CoreDataEvolution
import Foundation

final class Item: NSManagedObject {
  var date: Date? {
    get {
      value(forKey: "timestamp") as? Date
    }
    set {
      setValue(newValue, forKey: "timestamp")
    }
  }

  private static let __cd_attribute_validate_date_nonrelationship: Void = CoreDataEvolution
    ._CDAttributeMacroValidation.requireNonRelationship(Date?.self)

  var title: String {
    get {
      guard let value = value(forKey: "title") as? String else {
        preconditionFailure("Missing required value for `title` (title).")
      }
      return value
    }
    set {
      setValue(newValue, forKey: "title")
    }
  }

  private static let __cd_attribute_validate_title_nonrelationship: Void = CoreDataEvolution
    ._CDAttributeMacroValidation.requireNonRelationship(String.self)
  var transientCache: [String: Int] = [:]

  var tags: Set<Tag> {
    get {
      (value(forKey: "tags") as? NSSet)?
        .compactMap {
          $0 as? Tag
        }
        .reduce(into: Set<Tag>()) {
          $0.insert($1)
        }
        ?? []
    }
    set {
      setValue(NSSet(set: newValue), forKey: "tags")
    }
  }
  var orderedTags: [Tag] {
    (value(forKey: "orderedTags") as? NSOrderedSet)?
      .compactMap {
        $0 as? Tag
      }
      ?? []
  }
  var category: Category? {
    get {
      value(forKey: "category") as? Category
    }
    set {
      setValue(newValue, forKey: "category")
    }
  }

  enum Keys: String {
    case date = "timestamp"
    case title = "title"
  }

  enum Paths {
    static let date = CoreDataEvolution.CDPath<Item, Date?>(
      swiftPath: ["date"],
      persistentPath: ["timestamp"],
      storageMethod: .default
    )

    static let title = CoreDataEvolution.CDPath<Item, String>(
      swiftPath: ["title"],
      persistentPath: ["title"],
      storageMethod: .default
    )

    static let tags = CoreDataEvolution.CDToManyRelationPath<Item, Tag>(
      swiftPath: ["tags"],
      persistentPath: ["tags"]
    )

    static let orderedTags = CoreDataEvolution.CDToManyRelationPath<Item, Tag>(
      swiftPath: ["orderedTags"],
      persistentPath: ["orderedTags"]
    )

    static let category = CoreDataEvolution.CDToOneRelationPath<Item, Category>(
      swiftPath: ["category"],
      persistentPath: ["category"]
    )
  }

  struct PathRoot: Sendable {
    var date: CoreDataEvolution.CDPath<Item, Date?> {
      Paths.date
    }

    var title: CoreDataEvolution.CDPath<Item, String> {
      Paths.title
    }

    var tags: CoreDataEvolution.CDToManyRelationPath<Item, Tag> {
      Paths.tags
    }

    var orderedTags: CoreDataEvolution.CDToManyRelationPath<Item, Tag> {
      Paths.orderedTags
    }

    var category: CoreDataEvolution.CDToOneRelationPath<Item, Category> {
      Paths.category
    }
  }

  static var path: PathRoot {
    .init()
  }

  static let __cdFieldTable: [String: CoreDataEvolution.CDFieldMeta] = {
    var table: [String: CoreDataEvolution.CDFieldMeta] = [
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
      "tags": .init(
        kind: .relationship,
        swiftPath: ["tags"],
        persistentPath: ["tags"],
        storageMethod: .default,
        supportsStoreSort: false,
        isToManyRelationship: true
      ),
      "orderedTags": .init(
        kind: .relationship,
        swiftPath: ["orderedTags"],
        persistentPath: ["orderedTags"],
        storageMethod: .default,
        supportsStoreSort: false,
        isToManyRelationship: true
      ),
      "category": .init(
        kind: .relationship,
        swiftPath: ["category"],
        persistentPath: ["category"],
        storageMethod: .default,
        supportsStoreSort: false,
        isToManyRelationship: false
      ),
    ]
    table.merge(
      CoreDataEvolution.CDRelationshipTableBuilder.makeToManyFieldEntries(
        modelSwiftPathPrefix: ["tags"],
        modelPersistentPathPrefix: ["tags"],
        target: Tag.self
      ),
      uniquingKeysWith: { _, new in
        new
      }
    )
    table.merge(
      CoreDataEvolution.CDRelationshipTableBuilder.makeToManyFieldEntries(
        modelSwiftPathPrefix: ["orderedTags"],
        modelPersistentPathPrefix: ["orderedTags"],
        target: Tag.self
      ),
      uniquingKeysWith: { _, new in
        new
      }
    )
    table.merge(
      CoreDataEvolution.CDRelationshipTableBuilder.makeToOneFieldEntries(
        modelSwiftPathPrefix: ["category"],
        modelPersistentPathPrefix: ["category"],
        target: Category.self
      ),
      uniquingKeysWith: { _, new in
        new
      }
    )
    return table
  }()

  convenience init(
    date: Date? = nil,
    title: String = ""
  ) {
    self.init(entity: Self.entity(), insertInto: nil)
    self.date = date
    self.title = title
  }

  func addToTags(_ value: Tag) {
    mutableSetValue(forKey: "tags").add(value)
  }

  func removeFromTags(_ value: Tag) {
    mutableSetValue(forKey: "tags").remove(value)
  }

  func replaceTags(with values: Set<Tag>) {
    setValue(NSSet(set: values), forKey: "tags")
  }

  func addToOrderedTags(_ value: Tag) {
    mutableOrderedSetValue(forKey: "orderedTags").add(value)
  }

  func removeFromOrderedTags(_ value: Tag) {
    mutableOrderedSetValue(forKey: "orderedTags").remove(value)
  }
}

extension Item: CoreDataEvolution.PersistentEntity {
}
