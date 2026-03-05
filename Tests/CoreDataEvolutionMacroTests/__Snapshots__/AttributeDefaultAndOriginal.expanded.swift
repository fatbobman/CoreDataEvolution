import CoreDataEvolution
import Foundation

struct Item {
  var date: Date? {
    get {
      value(forKey: "timestamp") as? Date
    }
    set {
      setValue(newValue, forKey: "timestamp")
    }
  }

  private func __cd_attribute_validate_date_nonrelationship() {
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
    __cdDisallowRelationship(Date?.self)
  }
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

  private func __cd_attribute_validate_count_nonrelationship() {
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
    __cdDisallowRelationship(Int?.self)
  }
}
