import CoreDataEvolution
import Foundation

struct Config: Codable {
  let name: String
}

struct Item {
  var config: Config? {
    get {
      guard let data = value(forKey: "config") as? Data,
        let value = try? JSONDecoder().decode(Config.self, from: data)
      else {
        return nil
      }
      return value
    }
    set {
      if let newValue {
        do {
          let data = try JSONEncoder().encode(newValue)
          setValue(data, forKey: "config")
        } catch {
          let fallback: Config? = nil
          if let fallback {
            let data = try? JSONEncoder().encode(fallback)
            setValue(data, forKey: "config")
          } else {
            setValue(nil, forKey: "config")
          }
        }
      } else {
        setValue(nil, forKey: "config")
      }
    }
  }

  private func __cd_attribute_validate_config_nonrelationship() {
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
    __cdDisallowRelationship(Config?.self)
  }

  private func __cd_attribute_validate_config_codable() {
    func __cdRequireCodable<T: Codable>(_: T.Type) {
    }
    __cdRequireCodable(Config.self)
  }
}
