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

  private func __cd_attribute_validate_status_raw() {
    func __cdRequireRawRepresentable<T: RawRepresentable>(_: T.Type) {
    }
    __cdRequireRawRepresentable(Status.self)
  }
}
