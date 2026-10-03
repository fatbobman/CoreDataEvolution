import CoreDataEvolutionSchemaSupport
import SwiftParser
import SwiftSyntax

/// Decode literals once so macro metadata and cde-tool compare the same ICU pattern value.
func parseAttributeValidationRules(_ attribute: AttributeSyntax) throws
  -> CDAttributeValidationRules
{
  var arguments: [String: String] = [:]
  var regex: String?
  if let list = attribute.arguments?.as(LabeledExprListSyntax.self) {
    for argument in list {
      guard let label = argument.label?.text,
        CDAttributeValidationRules.argumentLabels.contains(label)
      else { continue }
      guard arguments[label] == nil else {
        throw CDAttributeValidationError.invalid(
          "Duplicate attribute validation argument `\(label)`.")
      }
      arguments[label] = argument.expression.trimmedDescription
      if label == "regex" {
        regex = argument.expression.as(StringLiteralExprSyntax.self)?.representedLiteralValue
      }
    }
  }
  return try .parse(arguments: arguments, decodedRegex: regex)
}
