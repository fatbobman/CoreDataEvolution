import CoreDataEvolution
import Foundation

@objc(ValidatedItem)
final class ValidatedItem: NSManagedObject {
  var title: String? {
    get {
      value(forKey: "name") as? String
    }
    set {
      setValue(newValue, forKey: "name")
    }
  }

  private static let __cd_attribute_validate_title_nonrelationship: Void = CoreDataEvolution._CDAttributeMacroValidation.requireNonRelationship(String?.self)
  var count: Int? {
    get {
      guard let number = value(forKey: "count") as? NSNumber else {
        return nil
      }
      return number.intValue
    }
    set {
      if let newValue {
        setValue(NSNumber(value: newValue), forKey: "count")
      } else {
        setValue(nil, forKey: "count")
      }
    }
  }

  private static let __cd_attribute_validate_count_nonrelationship: Void = CoreDataEvolution._CDAttributeMacroValidation.requireNonRelationship(Int?.self)
  var precise: Int64? {
    get {
      guard let number = value(forKey: "precise") as? NSNumber else {
        return nil
      }
      return number.int64Value
    }
    set {
      if let newValue {
        setValue(NSNumber(value: newValue), forKey: "precise")
      } else {
        setValue(nil, forKey: "precise")
      }
    }
  }

  private static let __cd_attribute_validate_precise_nonrelationship: Void = CoreDataEvolution._CDAttributeMacroValidation.requireNonRelationship(Int64?.self)
  var amount: Decimal? {
    get {
      guard let number = value(forKey: "amount") as? NSNumber else {
        return nil
      }
      return number.decimalValue
    }
    set {
      if let newValue {
        setValue(NSDecimalNumber(decimal: newValue), forKey: "amount")
      } else {
        setValue(nil, forKey: "amount")
      }
    }
  }

  private static let __cd_attribute_validate_amount_nonrelationship: Void = CoreDataEvolution._CDAttributeMacroValidation.requireNonRelationship(Decimal?.self)
  var timestamp: Date? {
    get {
      value(forKey: "timestamp") as? Date
    }
    set {
      setValue(newValue, forKey: "timestamp")
    }
  }

  private static let __cd_attribute_validate_timestamp_nonrelationship: Void = CoreDataEvolution._CDAttributeMacroValidation.requireNonRelationship(Date?.self)

  enum Keys: String {
    case title = "name"
    case count = "count"
    case precise = "precise"
    case amount = "amount"
    case timestamp = "timestamp"
  }

  enum Paths {
    static let title = CoreDataEvolution.CDPath<ValidatedItem, String?>(
      swiftPath: ["title"],
      persistentPath: ["name"],
      storageMethod: .default
    )

    static let count = CoreDataEvolution.CDPath<ValidatedItem, Int?>(
      swiftPath: ["count"],
      persistentPath: ["count"],
      storageMethod: .default
    )

    static let precise = CoreDataEvolution.CDPath<ValidatedItem, Int64?>(
      swiftPath: ["precise"],
      persistentPath: ["precise"],
      storageMethod: .default
    )

    static let amount = CoreDataEvolution.CDPath<ValidatedItem, Decimal?>(
      swiftPath: ["amount"],
      persistentPath: ["amount"],
      storageMethod: .default
    )

    static let timestamp = CoreDataEvolution.CDPath<ValidatedItem, Date?>(
      swiftPath: ["timestamp"],
      persistentPath: ["timestamp"],
      storageMethod: .default
    )
  }

  struct PathRoot: Sendable {
    var title: CoreDataEvolution.CDPath<ValidatedItem, String?> {
      Paths.title
    }

    var count: CoreDataEvolution.CDPath<ValidatedItem, Int?> {
      Paths.count
    }

    var precise: CoreDataEvolution.CDPath<ValidatedItem, Int64?> {
      Paths.precise
    }

    var amount: CoreDataEvolution.CDPath<ValidatedItem, Decimal?> {
      Paths.amount
    }

    var timestamp: CoreDataEvolution.CDPath<ValidatedItem, Date?> {
      Paths.timestamp
    }
  }

  static var path: PathRoot {
    .init()
  }

  static let __cdRelationshipProjectionTable: [String: CoreDataEvolution.CDFieldMeta] = {
    var table: [String: CoreDataEvolution.CDFieldMeta] = [
      "title": .init(
        kind: .attribute,
        swiftPath: ["title"],
        persistentPath: ["name"],
        storageMethod: .default,
        supportsStoreSort: true
        ),
      "count": .init(
        kind: .attribute,
        swiftPath: ["count"],
        persistentPath: ["count"],
        storageMethod: .default,
        supportsStoreSort: true
        ),
      "precise": .init(
        kind: .attribute,
        swiftPath: ["precise"],
        persistentPath: ["precise"],
        storageMethod: .default,
        supportsStoreSort: true
        ),
      "amount": .init(
        kind: .attribute,
        swiftPath: ["amount"],
        persistentPath: ["amount"],
        storageMethod: .default,
        supportsStoreSort: true
        ),
      "timestamp": .init(
        kind: .attribute,
        swiftPath: ["timestamp"],
        persistentPath: ["timestamp"],
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

      ],
      uniquingKeysWith: { _, new in
        new
      }
    )

    return table
  }()

  static var __cdRuntimeEntitySchema: CoreDataEvolution.CDRuntimeEntitySchema {
    .init(
      entityName: "ValidatedItem",
      managedObjectClassName: NSStringFromClass(Self.self),
      attributes: [
        CoreDataEvolution.CDRuntimeAttributeSchema(
    swiftName: "title",
    persistentName: "name",
    swiftTypeName: "String?",
    isOptional: true,
    defaultValueExpression: "nil",
    storage: .primitive(.string),
    isUnique: false,
        validation: .init(minimumLength: 1, maximumLength: 8, regularExpression: ".*\\S.*")
        ),
        CoreDataEvolution.CDRuntimeAttributeSchema(
          swiftName: "count",
          persistentName: "count",
          swiftTypeName: "Int?",
          isOptional: true,
          defaultValueExpression: "nil",
          storage: .primitive(.int64),
          isUnique: false,
              validation: .init(minimumValue: "0", maximumValue: "255")
        ),
        CoreDataEvolution.CDRuntimeAttributeSchema(
          swiftName: "precise",
          persistentName: "precise",
          swiftTypeName: "Int64?",
          isOptional: true,
          defaultValueExpression: "nil",
          storage: .primitive(.int64),
          isUnique: false,
              validation: .init(minimumValue: "9007199254740993", maximumValue: "9223372036854775807")
        ),
        CoreDataEvolution.CDRuntimeAttributeSchema(
          swiftName: "amount",
          persistentName: "amount",
          swiftTypeName: "Decimal?",
          isOptional: true,
          defaultValueExpression: "nil",
          storage: .primitive(.decimal),
          isUnique: false,
              validation: .init(minimumValue: "0.125", maximumValue: "1.25")
        ),
        CoreDataEvolution.CDRuntimeAttributeSchema(
          swiftName: "timestamp",
          persistentName: "timestamp",
          swiftTypeName: "Date?",
          isOptional: true,
          defaultValueExpression: "nil",
          storage: .primitive(.date),
          isUnique: false,
              validation: .init(minimumDate: 0.0, maximumDate: 120.0)
        )
      ],
      relationships: [

      ],
      uniquenessConstraints: [

      ]
    )
  }

  @nonobjc
  class func fetchRequest() -> NSFetchRequest<ValidatedItem> {
    NSFetchRequest<ValidatedItem>(entityName: "ValidatedItem")
  }
}

extension ValidatedItem: CoreDataEvolution.PersistentEntity, CoreDataEvolution.CDRuntimeSchemaProviding {
}