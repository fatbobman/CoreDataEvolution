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

  private static let __cd_attribute_validate_date_nonrelationship: Void = CoreDataEvolution._CDAttributeMacroValidation.requireNonRelationship(Date?.self)
  var count: Int? {
    get {
      guard let number = value(forKey: "count") as? NSNumber else {
        return nil
      }
      guard let result = Int(exactly: number) else {
        preconditionFailure("Stored value for `count` (count) cannot be represented as Int on this platform.")
      }
      return result
    }
    set {
      if let newValue {
        setValue(NSNumber(value: newValue), forKey: "count")
      } else {
        setValue(nil, forKey: "count")
      }
    }
  }

  private static let __cd_attribute_validate_count_nonrelationship: Void = CoreDataEvolution._CDAttributeMacroValidation.requireNonRelationship(Int?.self)
  var requiredCount: Int {
    get {
      guard let number = value(forKey: "required_count") as? NSNumber else {
        preconditionFailure("Missing required value for `requiredCount` (required_count).")
      }
      guard let result = Int(exactly: number) else {
        preconditionFailure("Stored value for `requiredCount` (required_count) cannot be represented as Int on this platform.")
      }
      return result
    }
    set {
      setValue(NSNumber(value: newValue), forKey: "required_count")
    }
  }

  private static let __cd_attribute_validate_requiredCount_nonrelationship: Void = CoreDataEvolution._CDAttributeMacroValidation.requireNonRelationship(Int.self)
}