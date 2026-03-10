import CoreData
import CoreDataEvolution
import Foundation

@objc(Item)
final class Item: NSManagedObject {
  var date: Date? {
    get {
      value(forKey: "timestamp") as? Date
    }
    set {
      setValue(newValue, forKey: "timestamp")
    }
  }

  private static let __cd_attribute_validate_date_nonrelationship: Void = CoreDataEvolution._CDAttributeMacroValidation.requireNonRelationship(Date?.self)

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

  private static let __cd_attribute_validate_title_nonrelationship: Void = CoreDataEvolution._CDAttributeMacroValidation.requireNonRelationship(String.self)
  var transientCache: [String: Int] = [:]
  var tags: Set<Tag> {
    get {
      // Expose a plain Swift Set<T> at the public API boundary.
      // This bridges and copies the underlying NSSet on every access.
      (value(forKey: "tags") as? NSSet)?
        .compactMap {
        $0 as? Tag
      }
        .reduce(into: Set<Tag>()) {
        $0.insert($1)
      }
        ?? []
    }
  }
  var orderedTags: [Tag] {
    get {
      // Expose a plain Swift [T] at the public API boundary.
      // This bridges and copies the underlying NSOrderedSet on every access.
      (value(forKey: "orderedTags") as? NSOrderedSet)?
        .compactMap {
        $0 as? Tag
      }
        ?? []
    }
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

  static let __cdRelationshipProjectionTable: [String: CoreDataEvolution.CDFieldMeta] = {
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
        )
      ]

    return table
  }()

  static let __cdFieldTable: [String: CoreDataEvolution.CDFieldMeta] = {
    var table: [String: CoreDataEvolution.CDFieldMeta] = __cdRelationshipProjectionTable
    table.merge(
      [
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
      )
      ],
      uniquingKeysWith: { _, new in
        new
      }
    )
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

  static let __cd_relationship_validate_tags_entity: Void = CoreDataEvolution._CDRelationshipMacroValidation.requirePersistentEntity(Tag.self)

  static let __cd_relationship_validate_orderedTags_entity: Void = CoreDataEvolution._CDRelationshipMacroValidation.requirePersistentEntity(Tag.self)

  static let __cd_relationship_validate_category_entity: Void = CoreDataEvolution._CDRelationshipMacroValidation.requirePersistentEntity(Category.self)

  static var __cdRuntimeEntitySchema: CoreDataEvolution.CDRuntimeEntitySchema {
    .init(
      entityName: "Item",
      managedObjectClassName: NSStringFromClass(Self.self),
      attributes: [
        CoreDataEvolution.CDRuntimeAttributeSchema(
    swiftName: "date",
    persistentName: "timestamp",
    swiftTypeName: "Date?",
    isOptional: true,
    defaultValueExpression: "nil",
    storage: .primitive(.date),
    isUnique: false
        ),
        CoreDataEvolution.CDRuntimeAttributeSchema(
          swiftName: "title",
          persistentName: "title",
          swiftTypeName: "String",
          isOptional: false,
          defaultValueExpression: "\"\"",
          storage: .primitive(.string),
          isUnique: false
        )
      ],
      relationships: [
        CoreDataEvolution.CDRuntimeRelationshipSchema(
    swiftName: "tags",
    persistentName: "tags",
    targetTypeName: "Tag",
    inverseName: "items",
    deleteRule: .nullify,
    kind: .toManySet,
    isOptional: true
        ),
        CoreDataEvolution.CDRuntimeRelationshipSchema(
          swiftName: "orderedTags",
          persistentName: "orderedTags",
          targetTypeName: "Tag",
          inverseName: "orderedItems",
          deleteRule: .nullify,
          kind: .toManyArray,
          isOptional: true
        ),
        CoreDataEvolution.CDRuntimeRelationshipSchema(
          swiftName: "category",
          persistentName: "category",
          targetTypeName: "Category",
          inverseName: "category",
          deleteRule: .nullify,
          kind: .toOne,
          isOptional: true
        )
      ],
      uniquenessConstraints: [

      ]
    )
  }

  convenience init(
    date: Date?,
    title: String,
    transientCache: [String: Int]
  ) {
    self.init(entity: Self.entity(), insertInto: nil)
    self.date = date
    self.title = title
    self.transientCache = transientCache
  }

  @nonobjc
  class func fetchRequest() -> NSFetchRequest<Item> {
    NSFetchRequest<Item>(entityName: "Item")
  }

  func addToTags(_ value: Tag) {
    mutableSetValue(forKey: "tags").add(value)
  }

  func removeFromTags(_ value: Tag) {
    mutableSetValue(forKey: "tags").remove(value)
  }

  func addToTags(_ values: Set<Tag>) {
    let mutable = mutableSetValue(forKey: "tags")
    for value in values {
      mutable.add(value)
    }
  }

  func removeFromTags(_ values: Set<Tag>) {
    let mutable = mutableSetValue(forKey: "tags")
    for value in values {
      mutable.remove(value)
    }
  }

  func addToOrderedTags(_ value: Tag) {
    mutableOrderedSetValue(forKey: "orderedTags").add(value)
  }

  func removeFromOrderedTags(_ value: Tag) {
    mutableOrderedSetValue(forKey: "orderedTags").remove(value)
  }

  func addToOrderedTags(_ values: [Tag]) {
    let mutable = mutableOrderedSetValue(forKey: "orderedTags")
    for value in values {
      mutable.add(value)
    }
  }

  func removeFromOrderedTags(_ values: [Tag]) {
    let mutable = mutableOrderedSetValue(forKey: "orderedTags")
    for value in values {
      mutable.remove(value)
    }
  }

  func insertIntoOrderedTags(_ value: Tag, at index: Int) {
    mutableOrderedSetValue(forKey: "orderedTags").insert(value, at: index)
  }
}

extension Item: CoreDataEvolution.PersistentEntity, CoreDataEvolution.CDRuntimeSchemaProviding {
}