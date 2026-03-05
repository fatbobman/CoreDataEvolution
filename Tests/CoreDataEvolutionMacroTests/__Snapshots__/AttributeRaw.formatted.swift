import CoreDataEvolution

enum Status: String {
  case a
  case b
}

struct Item {
  var status: Status? {
    get {
      guard let rawValue = value(forKey: "status") as? Status.RawValue,
        let value = Status.init(rawValue: rawValue)
      else {
        return .a
      }
      return value
    }
    set {
      setValue(newValue?.rawValue, forKey: "status")
    }
  }

  private func __cd_attribute_validate_status_nonrelationship() {
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
    __cdDisallowRelationship(Status?.self)
  }

  private func __cd_attribute_validate_status_raw() {
    func __cdRequireRawRepresentable<T: RawRepresentable>(_: T.Type) {
    }
    __cdRequireRawRepresentable(Status.self)
  }
}
