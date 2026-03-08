import CoreDataEvolution
import Foundation

final class ColorTransformer: ValueTransformer {}

struct Item {
  var color: String? {
    get {
      let transformer = ColorTransformer.self.init()
      let storedValue = value(forKey: "color")
      if let value = storedValue as? String {
        return value
      }
      guard let value = transformer.reverseTransformedValue(storedValue) as? String else {
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

  private static let __cd_attribute_validate_color_nonrelationship: Void = CoreDataEvolution._CDAttributeMacroValidation.requireNonRelationship(String?.self)

  private static let __cd_attribute_validate_color_transformed: Void = CoreDataEvolution._CDAttributeMacroValidation.requireTransformer(ColorTransformer.self.self)
}