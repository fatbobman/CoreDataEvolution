import CoreDataEvolution
import Foundation

struct Item {
  var color: String? {
    get {
      let storedValue = value(forKey: "color")
      if let value = storedValue as? String {
        return value
      }
      return nil
    }
    set {
      setValue(newValue, forKey: "color")
    }
  }

  private static let __cd_attribute_validate_color_nonrelationship: Void = CoreDataEvolution._CDAttributeMacroValidation.requireNonRelationship(String?.self)
}