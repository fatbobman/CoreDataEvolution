import Foundation
import SwiftSyntax

func parseStringLiteral(_ expression: ExprSyntax) -> String? {
  guard
    let literal = expression.as(StringLiteralExprSyntax.self),
    literal.segments.count == 1,
    let segment = literal.segments.first?.as(StringSegmentSyntax.self)
  else {
    return nil
  }
  return segment.content.text
}

func escapeStringLiteral(_ text: String) -> String {
  text
    .replacingOccurrences(of: "\\", with: "\\\\")
    .replacingOccurrences(of: "\"", with: "\\\"")
}

/// Validates that a name is a legal Core Data field identifier (attribute, relationship, or
/// composition field persistent name): non-empty, starts with a letter or underscore, and
/// contains only letters, digits, and underscores.
func isValidCoreDataFieldName(_ name: String) -> Bool {
  guard name.isEmpty == false else {
    return false
  }
  let scalars = name.unicodeScalars
  guard let first = scalars.first else {
    return false
  }
  let letters = CharacterSet.letters
  let digits = CharacterSet.decimalDigits
  if letters.contains(first) == false && first != "_" {
    return false
  }
  for scalar in scalars.dropFirst() {
    if letters.contains(scalar) || digits.contains(scalar) || scalar == "_" {
      continue
    }
    return false
  }
  return true
}
