import CoreDataEvolution
import Foundation

@objc(IntegerWidthItem)
final class IntegerWidthItem: NSManagedObject {
  var count: Int {
    get {
      guard let number = value(forKey: "count") as? NSNumber else {
        preconditionFailure("Missing required value for `count` (count).")
      }
      guard let result = Int(exactly: number) else {
        preconditionFailure("Stored value for `count` (count) cannot be represented as Int on this platform.")
      }
      return result
    }
    set {
      setValue(NSNumber(value: newValue), forKey: "count")
    }
  }

  private static let __cd_attribute_validate_count_nonrelationship: Void = CoreDataEvolution._CDAttributeMacroValidation.requireNonRelationship(Int.self)
  var sequence: Int? {
    get {
      guard let number = value(forKey: "stored_sequence") as? NSNumber else {
        return nil
      }
      guard let result = Int(exactly: number) else {
        preconditionFailure("Stored value for `sequence` (stored_sequence) cannot be represented as Int on this platform.")
      }
      return result
    }
    set {
      if let newValue {
        setValue(NSNumber(value: newValue), forKey: "stored_sequence")
      } else {
        setValue(nil, forKey: "stored_sequence")
      }
    }
  }

  private static let __cd_attribute_validate_sequence_nonrelationship: Void = CoreDataEvolution._CDAttributeMacroValidation.requireNonRelationship(Int?.self)
  var qualified: Swift.Int? {
    get {
      guard let number = value(forKey: "qualified") as? NSNumber else {
        return nil
      }
      guard let result = Int(exactly: number) else {
        preconditionFailure("Stored value for `qualified` (qualified) cannot be represented as Int on this platform.")
      }
      return result
    }
    set {
      if let newValue {
        setValue(NSNumber(value: newValue), forKey: "qualified")
      } else {
        setValue(nil, forKey: "qualified")
      }
    }
  }

  private static let __cd_attribute_validate_qualified_nonrelationship: Void = CoreDataEvolution._CDAttributeMacroValidation.requireNonRelationship(Swift.Int?.self)

  var wide: Int64? {
    get {
      guard let number = value(forKey: "wide") as? NSNumber else {
        return nil
      }
      return number.int64Value
    }
    set {
      if let newValue {
        setValue(NSNumber(value: newValue), forKey: "wide")
      } else {
        setValue(nil, forKey: "wide")
      }
    }
  }

  private static let __cd_attribute_validate_wide_nonrelationship: Void = CoreDataEvolution._CDAttributeMacroValidation.requireNonRelationship(Int64?.self)
  var narrow: Int32? {
    get {
      guard let number = value(forKey: "narrow") as? NSNumber else {
        return nil
      }
      return number.int32Value
    }
    set {
      if let newValue {
        setValue(NSNumber(value: newValue), forKey: "narrow")
      } else {
        setValue(nil, forKey: "narrow")
      }
    }
  }

  private static let __cd_attribute_validate_narrow_nonrelationship: Void = CoreDataEvolution._CDAttributeMacroValidation.requireNonRelationship(Int32?.self)
  var scratch: Int = 0
  var payload: Int? {
    get {
      guard let data = value(forKey: "payload") as? Data,
        let value = try? JSONDecoder().decode(Int.self, from: data)
      else {
        return nil
      }
      return value
    }
    set {
      if let newValue {
        do {
          let data = try JSONEncoder().encode(newValue)
          setValue(data, forKey: "payload")
        } catch {
          let fallback: Int? = nil
          if let fallback {
            let data = try? JSONEncoder().encode(fallback)
            setValue(data, forKey: "payload")
          } else {
            setValue(nil, forKey: "payload")
          }
        }
      } else {
        setValue(nil, forKey: "payload")
      }
    }
  }

  private static let __cd_attribute_validate_payload_nonrelationship: Void = CoreDataEvolution._CDAttributeMacroValidation.requireNonRelationship(Int?.self)

  private static let __cd_attribute_validate_payload_codable: Void = CoreDataEvolution._CDAttributeMacroValidation.requireCodable(Int.self)

  var calculated: Int { 0 }

  #if _pointerBitWidth(_32)
  #warning("Model 'IntegerWidthItem' uses Int for Integer 64 attributes: count, sequence, qualified. Int is 32-bit on this target. Reading stored values outside the Int range terminates execution. Use Int64 if these attributes require the full stored range.")
  #endif

  enum Keys: String {
    case count = "count"
    case sequence = "stored_sequence"
    case qualified = "qualified"
    case wide = "wide"
    case narrow = "narrow"
    case payload = "payload"
  }

  enum Paths {
    static let count = CoreDataEvolution.CDPath<IntegerWidthItem, Int>(
      swiftPath: ["count"],
      persistentPath: ["count"],
      storageMethod: .default
    )

    static let sequence = CoreDataEvolution.CDPath<IntegerWidthItem, Int?>(
      swiftPath: ["sequence"],
      persistentPath: ["stored_sequence"],
      storageMethod: .default
    )

    static let qualified = CoreDataEvolution.CDPath<IntegerWidthItem, Swift.Int?>(
      swiftPath: ["qualified"],
      persistentPath: ["qualified"],
      storageMethod: .default
    )

    static let wide = CoreDataEvolution.CDPath<IntegerWidthItem, Int64?>(
      swiftPath: ["wide"],
      persistentPath: ["wide"],
      storageMethod: .default
    )

    static let narrow = CoreDataEvolution.CDPath<IntegerWidthItem, Int32?>(
      swiftPath: ["narrow"],
      persistentPath: ["narrow"],
      storageMethod: .default
    )

    static let payload = CoreDataEvolution.CDPath<IntegerWidthItem, Int?>(
      swiftPath: ["payload"],
      persistentPath: ["payload"],
      storageMethod: .codable
    )
  }

  struct PathRoot: Sendable {
    var count: CoreDataEvolution.CDPath<IntegerWidthItem, Int> {
      Paths.count
    }

    var sequence: CoreDataEvolution.CDPath<IntegerWidthItem, Int?> {
      Paths.sequence
    }

    var qualified: CoreDataEvolution.CDPath<IntegerWidthItem, Swift.Int?> {
      Paths.qualified
    }

    var wide: CoreDataEvolution.CDPath<IntegerWidthItem, Int64?> {
      Paths.wide
    }

    var narrow: CoreDataEvolution.CDPath<IntegerWidthItem, Int32?> {
      Paths.narrow
    }

    var payload: CoreDataEvolution.CDPath<IntegerWidthItem, Int?> {
      Paths.payload
    }
  }

  static var path: PathRoot {
    .init()
  }

  static let __cdRelationshipProjectionTable: [String: CoreDataEvolution.CDFieldMeta] = {
    var table: [String: CoreDataEvolution.CDFieldMeta] = [
      "count": .init(
        kind: .attribute,
        swiftPath: ["count"],
        persistentPath: ["count"],
        storageMethod: .default,
        supportsStoreSort: true
        ),
      "sequence": .init(
        kind: .attribute,
        swiftPath: ["sequence"],
        persistentPath: ["stored_sequence"],
        storageMethod: .default,
        supportsStoreSort: true
        ),
      "qualified": .init(
        kind: .attribute,
        swiftPath: ["qualified"],
        persistentPath: ["qualified"],
        storageMethod: .default,
        supportsStoreSort: true
        ),
      "wide": .init(
        kind: .attribute,
        swiftPath: ["wide"],
        persistentPath: ["wide"],
        storageMethod: .default,
        supportsStoreSort: true
        ),
      "narrow": .init(
        kind: .attribute,
        swiftPath: ["narrow"],
        persistentPath: ["narrow"],
        storageMethod: .default,
        supportsStoreSort: true
        ),
      "payload": .init(
        kind: .attribute,
        swiftPath: ["payload"],
        persistentPath: ["payload"],
        storageMethod: .codable,
        supportsStoreSort: false
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
      entityName: "IntegerWidthItem",
      managedObjectClassName: NSStringFromClass(Self.self),
      attributes: [
        CoreDataEvolution.CDRuntimeAttributeSchema(
    swiftName: "count",
    persistentName: "count",
    swiftTypeName: "Int",
    isOptional: false,
    defaultValueExpression: "0",
    storage: .primitive(.int64),
    isUnique: false
        ),
        CoreDataEvolution.CDRuntimeAttributeSchema(
          swiftName: "sequence",
          persistentName: "stored_sequence",
          swiftTypeName: "Int?",
          isOptional: true,
          defaultValueExpression: "nil",
          storage: .primitive(.int64),
          isUnique: false
        ),
        CoreDataEvolution.CDRuntimeAttributeSchema(
          swiftName: "qualified",
          persistentName: "qualified",
          swiftTypeName: "Swift.Int?",
          isOptional: true,
          defaultValueExpression: "nil",
          storage: .primitive(({
          #error("Unsupported runtime primitive type 'Swift.Int' in generated runtime schema.")
          return CoreDataEvolution.CDRuntimePrimitiveAttributeType.string
        }())),
          isUnique: false
        ),
        CoreDataEvolution.CDRuntimeAttributeSchema(
          swiftName: "wide",
          persistentName: "wide",
          swiftTypeName: "Int64?",
          isOptional: true,
          defaultValueExpression: "nil",
          storage: .primitive(.int64),
          isUnique: false
        ),
        CoreDataEvolution.CDRuntimeAttributeSchema(
          swiftName: "narrow",
          persistentName: "narrow",
          swiftTypeName: "Int32?",
          isOptional: true,
          defaultValueExpression: "nil",
          storage: .primitive(.int32),
          isUnique: false
        ),
        CoreDataEvolution.CDRuntimeAttributeSchema(
          swiftName: "payload",
          persistentName: "payload",
          swiftTypeName: "Int?",
          isOptional: true,
          defaultValueExpression: "nil",
          storage: .codable,
          isUnique: false
        )
      ],
      relationships: [

      ],
      uniquenessConstraints: [

      ]
    )
  }

  @nonobjc
  class func fetchRequest() -> NSFetchRequest<IntegerWidthItem> {
    NSFetchRequest<IntegerWidthItem>(entityName: "IntegerWidthItem")
  }
}

extension IntegerWidthItem: CoreDataEvolution.PersistentEntity, CoreDataEvolution.CDRuntimeSchemaProviding {
}