import CoreDataEvolution
import Foundation

final class ColorTransformer: ValueTransformer {
}

struct Item {
  var color: String? {
    get {
      let transformer = ColorTransformer.self.init()
      guard let value = transformer.reverseTransformedValue(value(forKey: "color")) as? String
      else {
        return nil
      }
      return value
    }
    set {
      let transformer = ColorTransformer.self.init()
      if let newValue {
        if let transformed = transformer.transformedValue(newValue) {
          setValue(transformed, forKey: "color")
          return
        }

        let fallback: String? = nil
        if let fallback, let transformed = transformer.transformedValue(fallback) {
          setValue(transformed, forKey: "color")
        } else {
          setValue(nil, forKey: "color")
        }
      } else {
        setValue(nil, forKey: "color")
      }
    }
  }

  private func __cd_attribute_validate_color_nonrelationship() {
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
    __cdDisallowRelationship(String?.self)
  }

  private func __cd_attribute_validate_color_transformed() {
    func __cdRequireTransformer<T: ValueTransformer>(_: T.Type) {
    }
    __cdRequireTransformer(ColorTransformer.self)
  }
}
