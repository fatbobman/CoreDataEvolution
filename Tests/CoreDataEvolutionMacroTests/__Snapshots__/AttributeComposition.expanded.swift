import CoreDataEvolution

struct Magnitude {
  var richter: Double

  static let __cdCompositionFieldTable: [String: CoreDataEvolution.CDCompositionFieldMeta] = [
    "richter": .init(swiftPath: ["richter"], persistentPath: ["richter"])
  ]

  static func __cdDecodeComposition(from dictionary: [String: Any]) -> Self? {
    guard let richter = dictionary["richter"] as? Double else { return nil }
    return .init(richter: richter)
  }

  var __cdEncodeComposition: [String: Any] {
    var dictionary: [String: Any] = [:]
    dictionary["richter"] = richter
    return dictionary
  }
}

struct Item {
  var magnitude: Magnitude? {
    get {
      guard let dictionary = value(forKey: "magnitude") as? [String: Any] else {
        return nil
      }
      return Magnitude.__cdDecodeComposition(from: dictionary)
    }
    set {
      setValue(newValue?.__cdEncodeComposition, forKey: "magnitude")
    }
  }

  private func __cd_attribute_validate_magnitude_nonrelationship() {
    func __cdDisallowRelationship<T>(_: T.Type) {
    }
    @available(
      *, unavailable,
      message:
        "@Attribute cannot be applied to relationship properties. Remove @Attribute from this property."
    )
    func __cdDisallowRelationship<T: NSManagedObject>(_: T.Type) {
    }
    @available(
      *, unavailable,
      message:
        "@Attribute cannot be applied to to-one relationship properties (`T?` where `T: NSManagedObject`)."
    )
    func __cdDisallowRelationship<T: NSManagedObject>(_: T?.Type) {
    }
    @available(
      *, unavailable,
      message:
        "@Attribute cannot be applied to to-many relationship properties (`Set<T>` where `T: NSManagedObject`)."
    )
    func __cdDisallowRelationship<T: NSManagedObject>(_: Set<T>.Type) {
    }
    @available(
      *, unavailable,
      message:
        "@Attribute cannot be applied to ordered to-many relationship properties (`[T]` where `T: NSManagedObject`)."
    )
    func __cdDisallowRelationship<T: NSManagedObject>(_: [T].Type) {
    }
    __cdDisallowRelationship(Magnitude?.self)
  }

  private func __cd_attribute_validate_magnitude_composition() {
    func __cdRequireComposition<T: CDCompositionValueCodable & CDCompositionPathProviding>(
      _: T.Type
    ) {
    }
    __cdRequireComposition(Magnitude.self)
  }
}

extension Magnitude: CoreDataEvolution.CDCompositionPathProviding, CoreDataEvolution
    .CDCompositionValueCodable
{
}
