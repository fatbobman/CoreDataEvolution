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

  private static let __cd_attribute_validate_config_nonrelationship: Void = CoreDataEvolution
    ._CDAttributeMacroValidation.requireNonRelationship(Config?.self)

  private static let __cd_attribute_validate_config_codable: Void = CoreDataEvolution
    ._CDAttributeMacroValidation.requireCodable(Config.self)
}
