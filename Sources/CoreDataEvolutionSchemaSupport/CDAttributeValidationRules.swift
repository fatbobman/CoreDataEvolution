import CoreData
import Foundation

/// Portable metadata for the built-in Core Data attribute validation rules.
/// Numeric bounds use decimal strings to preserve integer/decimal precision. Date bounds are
/// seconds since Apple's reference date. Validation runs at save time, never in generated setters.
public struct CDAttributeValidationRules: Codable, Sendable, Equatable {
  public var minimumValue: String?
  public var maximumValue: String?
  public var minimumLength: Int?
  public var maximumLength: Int?
  public var regularExpression: String?
  public var minimumDate: Double?
  public var maximumDate: Double?

  public init(
    minimumValue: String? = nil,
    maximumValue: String? = nil,
    minimumLength: Int? = nil,
    maximumLength: Int? = nil,
    regularExpression: String? = nil,
    minimumDate: Double? = nil,
    maximumDate: Double? = nil
  ) {
    self.minimumValue = minimumValue
    self.maximumValue = maximumValue
    self.minimumLength = minimumLength
    self.maximumLength = maximumLength
    self.regularExpression = regularExpression
    self.minimumDate = minimumDate
    self.maximumDate = maximumDate
  }

  public var isEmpty: Bool { self == Self() }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    let samePattern: Bool
    switch (lhs.regularExpression, rhs.regularExpression) {
    case (.none, .none): samePattern = true
    case (.some(let left), .some(let right)):
      // Swift String equality normalizes Unicode; ICU patterns must retain their exact scalars.
      samePattern = left.utf8.elementsEqual(right.utf8)
    default: samePattern = false
    }
    return lhs.minimumValue == rhs.minimumValue && lhs.maximumValue == rhs.maximumValue
      && lhs.minimumLength == rhs.minimumLength && lhs.maximumLength == rhs.maximumLength
      && samePattern && lhs.minimumDate == rhs.minimumDate && lhs.maximumDate == rhs.maximumDate
  }

  public static let argumentLabels: Set<String> = [
    "min", "max", "minLength", "maxLength", "regex", "minDate", "maxDate",
  ]

  /// Parses the supported literal subset shared by macros and source/model validation.
  /// `regex` must already be decoded by SwiftParser, including raw/multiline string semantics.
  public static func parse(
    arguments: [String: String],
    decodedRegex: String?
  ) throws -> Self {
    var rules = Self()
    for (label, expression) in arguments where expression != "nil" {
      switch label {
      case "min", "max":
        guard let number = decimalLiteral(expression) else {
          throw CDAttributeValidationError.invalid(
            "`\(label)` must be a finite decimal numeric literal exactly representable as Foundation Decimal, or nil; unsupported bounds cannot be tested faithfully."
          )
        }
        if label == "min" { rules.minimumValue = number } else { rules.maximumValue = number }
      case "minLength", "maxLength":
        let text = expression.replacingOccurrences(of: "_", with: "")
        guard text.range(of: #"^[+-]?[0-9]+$"#, options: .regularExpression) != nil,
          let integer = Int(text), integer >= 0
        else {
          throw CDAttributeValidationError.invalid(
            "`\(label)` must be a non-negative integer literal or nil.")
        }
        if label == "minLength" {
          rules.minimumLength = integer
        } else {
          rules.maximumLength = integer
        }
      case "regex":
        guard let decodedRegex else {
          throw CDAttributeValidationError.invalid(
            "`regex` must be a non-interpolated ICU pattern string literal or nil; Swift Regex literals are not supported."
          )
        }
        rules.regularExpression = decodedRegex
      case "minDate", "maxDate":
        guard let date = dateLiteral(expression) else {
          throw CDAttributeValidationError.invalid(
            "`\(label)` requires a fixed Date(timeIntervalSince1970:), Date(timeIntervalSinceReferenceDate:), .distantPast, .distantFuture, or nil; dynamic dates cannot be tested faithfully."
          )
        }
        if label == "minDate" { rules.minimumDate = date } else { rules.maximumDate = date }
      default:
        throw CDAttributeValidationError.invalid(
          "Unknown attribute validation argument `\(label)`.")
      }
    }
    try rules.validate()
    return rules
  }

  /// Rejects inconsistent ranges, invalid ICU patterns, and rules for unsupported storage types.
  public func validate(primitiveType: String? = nil) throws {
    let minimum = try minimumValue.map { try Self.decimal($0) }
    let maximum = try maximumValue.map { try Self.decimal($0) }
    if let minimum, let maximum, minimum > maximum {
      throw CDAttributeValidationError.invalid("`min` must not exceed `max`.")
    }
    if let minimumLength, minimumLength < 0 {
      throw CDAttributeValidationError.invalid("`minLength` must be non-negative.")
    }
    if let maximumLength, maximumLength < 0 {
      throw CDAttributeValidationError.invalid("`maxLength` must be non-negative.")
    }
    if let minimumLength, let maximumLength, minimumLength > maximumLength {
      throw CDAttributeValidationError.invalid("`minLength` must not exceed `maxLength`.")
    }
    if minimumDate?.isFinite == false || maximumDate?.isFinite == false {
      throw CDAttributeValidationError.invalid("Date validation bounds must be finite.")
    }
    if let minimumDate, let maximumDate, minimumDate > maximumDate {
      throw CDAttributeValidationError.invalid("`minDate` must not exceed `maxDate`.")
    }
    if let regularExpression {
      do { _ = try NSRegularExpression(pattern: regularExpression) } catch {
        throw CDAttributeValidationError.invalid(
          "Invalid ICU `regex`: \(error.localizedDescription)")
      }
    }
    guard let primitiveType, !isEmpty else { return }
    let numericTypes = ["Int", "Int16", "Int32", "Int64", "Float", "Double", "Decimal"]
    if (minimum != nil || maximum != nil) && !numericTypes.contains(primitiveType) {
      throw CDAttributeValidationError.invalid(
        "`min`/`max` only support numeric attributes with `.default` storage.")
    }
    if (minimumLength != nil || maximumLength != nil || regularExpression != nil)
      && primitiveType != "String"
    {
      throw CDAttributeValidationError.invalid(
        "Length and `regex` rules only support String attributes with `.default` storage.")
    }
    if (minimumDate != nil || maximumDate != nil) && primitiveType != "Date" {
      throw CDAttributeValidationError.invalid(
        "`minDate`/`maxDate` only support Date attributes with `.default` storage.")
    }
  }

  /// Reconstructs the predicates and numeric warning codes emitted by Xcode's model compiler.
  /// Install these before the model is attached to a persistent store coordinator.
  public func apply(to attribute: NSAttributeDescription) throws {
    try validate(primitiveType: Self.primitiveType(for: attribute.attributeType))
    var predicates: [NSPredicate] = []
    var warnings: [NSNumber] = []
    func append(_ format: String, _ value: Any, _ code: Int) {
      predicates.append(NSPredicate(format: format, argumentArray: [value]))
      warnings.append(NSNumber(value: code))
    }
    if let minimumValue {
      append(
        "SELF >= %@", NSDecimalNumber(decimal: try Self.decimal(minimumValue)),
        NSValidationNumberTooSmallError)
    }
    if let maximumValue {
      append(
        "SELF <= %@", NSDecimalNumber(decimal: try Self.decimal(maximumValue)),
        NSValidationNumberTooLargeError)
    }
    if let minimumLength { append("length >= %@", minimumLength, NSValidationStringTooShortError) }
    if let maximumLength { append("length <= %@", maximumLength, NSValidationStringTooLongError) }
    if let regularExpression {
      append("SELF MATCHES %@", regularExpression, NSValidationStringPatternMatchingError)
    }
    if let minimumDate {
      append("timeIntervalSinceReferenceDate >= %@", minimumDate, NSValidationDateTooSoonError)
    }
    if let maximumDate {
      append("timeIntervalSinceReferenceDate <= %@", maximumDate, NSValidationDateTooLateError)
    }
    // momc archives NSNumber error codes, but the Swift overlay only accepts [String]. Invoke the
    // same public Objective-C setter with the original Foundation objects to preserve native codes.
    attribute.perform(
      #selector(NSPropertyDescription.setValidationPredicates(_:withValidationWarnings:)),
      with: predicates as NSArray,
      with: warnings as NSArray
    )
  }

  /// Reads the supported built-in predicate shapes from a compiled model without guessing at
  /// arbitrary predicate equivalence. Unknown/custom predicates are reported, never discarded.
  public static func read(from attribute: NSAttributeDescription) throws -> Self {
    var rules = Self()
    guard attribute.validationWarnings.count == attribute.validationPredicates.count else {
      throw CDAttributeValidationError.invalid(
        "Model validation predicates and warnings are incomplete; use the real model for integration tests."
      )
    }
    func requireWarning(_ code: Int, at index: Int) throws {
      guard attribute.validationWarnings.count == attribute.validationPredicates.count,
        let warning = attribute.validationWarnings[index] as? NSNumber,
        warning.intValue == code
      else {
        throw CDAttributeValidationError.invalid(
          "Custom model validation warnings cannot be reproduced by built-in annotations; use the real model for integration tests."
        )
      }
    }
    for (index, predicate) in attribute.validationPredicates.enumerated() {
      guard let comparison = predicate as? NSComparisonPredicate,
        comparison.comparisonPredicateModifier == .direct, comparison.options.isEmpty,
        comparison.rightExpression.expressionType == .constantValue
      else { throw CDAttributeValidationError.unsupported(predicate.predicateFormat) }
      let lhs = comparison.leftExpression
      let value = comparison.rightExpression.constantValue
      let operation = comparison.predicateOperatorType
      if lhs.expressionType == .evaluatedObject,
        operation == .matches, attribute.attributeType == .stringAttributeType,
        let pattern = value as? String, rules.regularExpression == nil
      {
        rules.regularExpression = pattern
        try requireWarning(NSValidationStringPatternMatchingError, at: index)
        continue
      }
      guard operation == .greaterThanOrEqualTo || operation == .lessThanOrEqualTo,
        let number = value as? NSNumber
      else { throw CDAttributeValidationError.unsupported(predicate.predicateFormat) }
      let isMinimum = operation == .greaterThanOrEqualTo
      if lhs.expressionType == .evaluatedObject,
        ["Int16", "Int32", "Int64", "Float", "Double", "Decimal"].contains(
          primitiveType(for: attribute.attributeType))
      {
        let literal = try decimal(number.stringValue).description
        if isMinimum, rules.minimumValue == nil {
          rules.minimumValue = literal
        } else if !isMinimum, rules.maximumValue == nil {
          rules.maximumValue = literal
        } else {
          throw CDAttributeValidationError.unsupported(predicate.predicateFormat)
        }
        try requireWarning(
          isMinimum ? NSValidationNumberTooSmallError : NSValidationNumberTooLargeError, at: index)
      } else if lhs.expressionType == .keyPath, lhs.keyPath == "length",
        attribute.attributeType == .stringAttributeType,
        let length = Int(number.stringValue), length >= 0
      {
        if isMinimum, rules.minimumLength == nil {
          rules.minimumLength = length
        } else if !isMinimum, rules.maximumLength == nil {
          rules.maximumLength = length
        } else {
          throw CDAttributeValidationError.unsupported(predicate.predicateFormat)
        }
        try requireWarning(
          isMinimum ? NSValidationStringTooShortError : NSValidationStringTooLongError, at: index)
      } else if lhs.expressionType == .keyPath, lhs.keyPath == "timeIntervalSinceReferenceDate",
        attribute.attributeType == .dateAttributeType
      {
        if isMinimum, rules.minimumDate == nil {
          rules.minimumDate = number.doubleValue
        } else if !isMinimum, rules.maximumDate == nil {
          rules.maximumDate = number.doubleValue
        } else {
          throw CDAttributeValidationError.unsupported(predicate.predicateFormat)
        }
        try requireWarning(
          isMinimum ? NSValidationDateTooSoonError : NSValidationDateTooLateError, at: index)
      } else {
        throw CDAttributeValidationError.unsupported(predicate.predicateFormat)
      }
    }
    try rules.validate(primitiveType: primitiveType(for: attribute.attributeType))
    return rules
  }

  /// Canonical macro arguments, also used by tooling generation and annotation fixes.
  public var swiftArguments: [String] {
    var arguments: [String] = []
    if let minimumValue { arguments.append("min: \(minimumValue)") }
    if let maximumValue { arguments.append("max: \(maximumValue)") }
    if let minimumLength { arguments.append("minLength: \(minimumLength)") }
    if let maximumLength { arguments.append("maxLength: \(maximumLength)") }
    if let regularExpression { arguments.append("regex: \(String(reflecting: regularExpression))") }
    if let minimumDate {
      arguments.append("minDate: Date(timeIntervalSinceReferenceDate: \(minimumDate))")
    }
    if let maximumDate {
      arguments.append("maxDate: Date(timeIntervalSinceReferenceDate: \(maximumDate))")
    }
    return arguments
  }

  /// The schema initializer expression emitted by macros; bounds have already been validated.
  public var schemaExpression: String {
    var arguments: [String] = []
    if let minimumValue { arguments.append("minimumValue: \(String(reflecting: minimumValue))") }
    if let maximumValue { arguments.append("maximumValue: \(String(reflecting: maximumValue))") }
    if let minimumLength { arguments.append("minimumLength: \(minimumLength)") }
    if let maximumLength { arguments.append("maximumLength: \(maximumLength)") }
    if let regularExpression {
      arguments.append("regularExpression: \(String(reflecting: regularExpression))")
    }
    if let minimumDate { arguments.append("minimumDate: \(minimumDate)") }
    if let maximumDate { arguments.append("maximumDate: \(maximumDate)") }
    return ".init(\(arguments.joined(separator: ", ")))"
  }

  public static func primitiveType(for type: NSAttributeType) -> String {
    switch type {
    case .stringAttributeType: return "String"
    case .integer16AttributeType: return "Int16"
    case .integer32AttributeType: return "Int32"
    case .integer64AttributeType: return "Int64"
    case .floatAttributeType: return "Float"
    case .doubleAttributeType: return "Double"
    case .decimalAttributeType: return "Decimal"
    case .dateAttributeType: return "Date"
    default: return "<unsupported>"
    }
  }

  private static func decimal(_ text: String) throws -> Decimal {
    guard let shape = decimalShape(text),
      let value = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")), !value.isNaN,
      decimalShape(value.description) == shape
    else {
      throw CDAttributeValidationError.invalid(
        "Invalid or imprecise decimal validation bound '\(text)'; this rule cannot be tested faithfully."
      )
    }
    return value
  }

  private static func decimalLiteral(_ expression: String) -> String? {
    let text = expression.filter { !$0.isWhitespace && $0 != "_" }
    guard let value = try? decimal(text)
    else { return nil }
    return value.description
  }

  // Compare exact significant digits before accepting Foundation Decimal's bounded precision.
  // This accepts harmless zeros/exponent spelling while rejecting silently rounded bounds.
  private static func decimalShape(_ text: String) -> String? {
    guard
      text.range(
        of: #"^[+-]?[0-9]+(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?$"#, options: .regularExpression) != nil
    else { return nil }
    let negative = text.hasPrefix("-")
    let unsigned = (text.hasPrefix("-") || text.hasPrefix("+")) ? String(text.dropFirst()) : text
    let parts = unsigned.lowercased().split(separator: "e")
    guard let exponent = parts.count == 2 ? Int(parts[1]) : 0,
      (-1000...1000).contains(exponent)
    else { return nil }
    let fractionCount = parts[0].split(separator: ".").dropFirst().first?.count ?? 0
    var digits = parts[0].replacingOccurrences(of: ".", with: "")
    while digits.first == "0" { digits.removeFirst() }
    if digits.isEmpty { return "0" }
    var power = exponent - fractionCount
    while digits.last == "0" {
      digits.removeLast()
      power += 1
    }
    return "\(negative ? "-" : "")\(digits)e\(power)"
  }

  private static func dateLiteral(_ expression: String) -> Double? {
    let text = expression.filter { !$0.isWhitespace }
    if [".distantPast", "Date.distantPast", "Foundation.Date.distantPast"].contains(text) {
      return Date.distantPast.timeIntervalSinceReferenceDate
    }
    if [".distantFuture", "Date.distantFuture", "Foundation.Date.distantFuture"].contains(text) {
      return Date.distantFuture.timeIntervalSinceReferenceDate
    }
    for type in ["Date", "Foundation.Date"] {
      for label in ["timeIntervalSince1970", "timeIntervalSinceReferenceDate"] {
        let prefix = "\(type)(\(label):"
        guard text.hasPrefix(prefix), text.hasSuffix(")"),
          let literal = decimalLiteral(String(text.dropFirst(prefix.count).dropLast())),
          let number = Double(literal), number.isFinite
        else { continue }
        return label == "timeIntervalSince1970" ? number - 978_307_200 : number
      }
    }
    return nil
  }
}

/// A declared rule cannot be reproduced, or a model uses a predicate outside the supported subset.
public enum CDAttributeValidationError: LocalizedError, Sendable, Equatable {
  case invalid(String)
  case unsupported(String)

  public var errorDescription: String? {
    switch self {
    case .invalid(let message): return message
    case .unsupported(let predicate):
      return
        "Unsupported model validation predicate '\(predicate)'; pure-code tests cannot faithfully cover this rule. Use the real model for integration tests."
    }
  }
}
