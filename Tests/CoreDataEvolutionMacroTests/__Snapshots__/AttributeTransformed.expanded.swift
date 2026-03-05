import CoreDataEvolution
import Foundation

final class ColorTransformer: ValueTransformer {}

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

  private func __cd_attribute_validate_color_transformed() {
    func __cdRequireTransformer<T: ValueTransformer>(_: T.Type) {
    }
    __cdRequireTransformer(ColorTransformer.self)
  }
}
