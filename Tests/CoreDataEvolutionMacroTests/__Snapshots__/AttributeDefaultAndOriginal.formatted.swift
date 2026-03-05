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
}
