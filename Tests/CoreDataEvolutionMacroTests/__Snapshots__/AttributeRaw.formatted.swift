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

  private static let __cd_attribute_validate_status_nonrelationship: Void = CoreDataEvolution
    ._CDAttributeMacroValidation.requireNonRelationship(Status?.self)

  private static let __cd_attribute_validate_status_raw: Void = CoreDataEvolution
    ._CDAttributeMacroValidation.requireRawRepresentable(Status.self)
}
