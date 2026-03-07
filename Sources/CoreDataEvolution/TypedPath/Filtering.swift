//
//  ------------------------------------------------
//  Original project: CoreDataEvolution
//  Created on 2026/3/5 by Fatbobman(东坡肘子)
//  X: @fatbobman
//  Mastodon: @fatbobman@mastodon.social
//  GitHub: @fatbobman
//  Blog: https://fatbobman.com
//  ------------------------------------------------
//  Copyright © 2024-present Fatbobman. All rights reserved.

import Foundation

public enum CDCollectionQuantifier: String, Sendable {
  case any = "ANY"
  case all = "ALL"
  case none = "NONE"
}

/// Field wrapper that builds `%K`-based NSPredicate fragments.
public struct CDFilterField<Root: CoreDataPathTable, Value> {
  public let swiftPath: [String]
  public let quantifier: CDCollectionQuantifier?

  public init(
    swiftPath: [String],
    quantifier: CDCollectionQuantifier? = nil
  ) {
    self.swiftPath = swiftPath
    self.quantifier = quantifier
  }

  public var swiftPathKey: String {
    swiftPath.joined(separator: ".")
  }

  public var persistentPath: [String] {
    Root.__cdMeta(forSwiftPath: swiftPathKey)?.persistentPath ?? swiftPath
  }

  public var persistentPathKey: String {
    persistentPath.joined(separator: ".")
  }

  /// Convenience alias for persistent field key/path.
  public var raw: String {
    persistentPathKey
  }

  public func equals(_ value: Any) -> NSPredicate {
    buildPredicate(operator: "==", value: value)
  }

  public func notEquals(_ value: Any) -> NSPredicate {
    buildPredicate(operator: "!=", value: value)
  }

  /// Convenience overload for `.raw` storage paths. The enum or wrapper value is converted to its
  /// `rawValue` before building the `%K` predicate.
  public func equals<R: RawRepresentable>(_ value: R) -> NSPredicate {
    ensureRawStorage(method: "equals(_:)")
    return buildPredicate(operator: "==", value: value.rawValue)
  }

  /// Convenience overload for `.raw` storage paths. The enum or wrapper value is converted to its
  /// `rawValue` before building the `%K` predicate.
  public func notEquals<R: RawRepresentable>(_ value: R) -> NSPredicate {
    ensureRawStorage(method: "notEquals(_:)")
    return buildPredicate(operator: "!=", value: value.rawValue)
  }

  public func greaterThan(_ value: Any) -> NSPredicate {
    buildPredicate(operator: ">", value: value)
  }

  public func greaterThan<T: BinaryInteger>(_ value: T) -> NSPredicate {
    buildPredicate(operator: ">", value: NSNumber(value: Int64(value)))
  }

  public func greaterThan<T: BinaryFloatingPoint>(_ value: T) -> NSPredicate {
    buildPredicate(operator: ">", value: NSNumber(value: Double(value)))
  }

  public func greaterThanOrEqual(_ value: Any) -> NSPredicate {
    buildPredicate(operator: ">=", value: value)
  }

  public func greaterThanOrEqual<T: BinaryInteger>(_ value: T) -> NSPredicate {
    buildPredicate(operator: ">=", value: NSNumber(value: Int64(value)))
  }

  public func greaterThanOrEqual<T: BinaryFloatingPoint>(_ value: T) -> NSPredicate {
    buildPredicate(operator: ">=", value: NSNumber(value: Double(value)))
  }

  public func lessThan(_ value: Any) -> NSPredicate {
    buildPredicate(operator: "<", value: value)
  }

  public func lessThan<T: BinaryInteger>(_ value: T) -> NSPredicate {
    buildPredicate(operator: "<", value: NSNumber(value: Int64(value)))
  }

  public func lessThan<T: BinaryFloatingPoint>(_ value: T) -> NSPredicate {
    buildPredicate(operator: "<", value: NSNumber(value: Double(value)))
  }

  public func lessThanOrEqual(_ value: Any) -> NSPredicate {
    buildPredicate(operator: "<=", value: value)
  }

  public func lessThanOrEqual<T: BinaryInteger>(_ value: T) -> NSPredicate {
    buildPredicate(operator: "<=", value: NSNumber(value: Int64(value)))
  }

  public func lessThanOrEqual<T: BinaryFloatingPoint>(_ value: T) -> NSPredicate {
    buildPredicate(operator: "<=", value: NSNumber(value: Double(value)))
  }

  public func contains(_ value: String, caseInsensitive: Bool = true) -> NSPredicate {
    let op = caseInsensitive ? "CONTAINS[cd]" : "CONTAINS"
    return buildPredicate(operator: op, value: value)
  }

  private func buildPredicate(
    `operator`: String,
    value: Any
  ) -> NSPredicate {
    let key = persistentPathKey
    let boxedValue = boxPredicateValue(value)
    if let quantifier {
      switch quantifier {
      case .any:
        let format = "ANY %K \(`operator`) %@"
        return NSPredicate(format: format, argumentArray: [key, boxedValue])
      case .none:
        // Use explicit NOT ANY for Core Data compatibility.
        let format = "ANY %K \(`operator`) %@"
        let anyPredicate = NSPredicate(format: format, argumentArray: [key, boxedValue])
        return NSCompoundPredicate(notPredicateWithSubpredicate: anyPredicate)
      case .all:
        // `ALL A op B` => `NOT (ANY A inverse(op) B)`
        let inverseOperator = inverse(of: `operator`)
        let format = "ANY %K \(inverseOperator) %@"
        let anyInverse = NSPredicate(format: format, argumentArray: [key, boxedValue])
        return NSCompoundPredicate(notPredicateWithSubpredicate: anyInverse)
      }
    }
    let format = "%K \(`operator`) %@"
    return NSPredicate(format: format, argumentArray: [key, boxedValue])
  }

  private func boxPredicateValue(_ value: Any) -> Any {
    switch value {
    case let n as NSNumber:
      return n
    case let i as Int:
      return NSNumber(value: i)
    case let i8 as Int8:
      return NSNumber(value: i8)
    case let i16 as Int16:
      return NSNumber(value: i16)
    case let i32 as Int32:
      return NSNumber(value: i32)
    case let i64 as Int64:
      return NSNumber(value: i64)
    case let u as UInt:
      return NSNumber(value: u)
    case let u8 as UInt8:
      return NSNumber(value: u8)
    case let u16 as UInt16:
      return NSNumber(value: u16)
    case let u32 as UInt32:
      return NSNumber(value: u32)
    case let u64 as UInt64:
      return NSNumber(value: u64)
    case let f as Float:
      return NSNumber(value: f)
    case let d as Double:
      return NSNumber(value: d)
    case let b as Bool:
      return NSNumber(value: b)
    default:
      return value
    }
  }

  private func inverse(of `operator`: String) -> String {
    switch `operator` {
    case "==": return "!="
    case "!=": return "=="
    case ">": return "<="
    case ">=": return "<"
    case "<": return ">="
    case "<=": return ">"
    case "CONTAINS": return "NOT CONTAINS"
    case "CONTAINS[cd]": return "NOT CONTAINS[cd]"
    default: return "!="
    }
  }

  private func ensureRawStorage(method: String) {
    let storageMethod = Root.__cdMeta(forSwiftPath: swiftPathKey)?.storageMethod
    precondition(
      storageMethod == .raw,
      "TypedPath \(method) RawRepresentable overload only supports paths declared with `.raw` storage."
    )
  }
}

extension CDPath where Root: CoreDataPathTable {
  public var filterField: CDFilterField<Root, Value> {
    CDFilterField(swiftPath: swiftPath)
  }

  public func equals(_ value: Any) -> NSPredicate {
    filterField.equals(value)
  }

  public func notEquals(_ value: Any) -> NSPredicate {
    filterField.notEquals(value)
  }

  public func equals<R: RawRepresentable>(_ value: R) -> NSPredicate {
    filterField.equals(value)
  }

  public func notEquals<R: RawRepresentable>(_ value: R) -> NSPredicate {
    filterField.notEquals(value)
  }

  public func greaterThan(_ value: Any) -> NSPredicate {
    filterField.greaterThan(value)
  }

  public func lessThan(_ value: Any) -> NSPredicate {
    filterField.lessThan(value)
  }

  public func greaterThanOrEqual(_ value: Any) -> NSPredicate {
    filterField.greaterThanOrEqual(value)
  }

  public func lessThanOrEqual(_ value: Any) -> NSPredicate {
    filterField.lessThanOrEqual(value)
  }

  public func contains(_ value: String, caseInsensitive: Bool = true) -> NSPredicate {
    filterField.contains(value, caseInsensitive: caseInsensitive)
  }
}
