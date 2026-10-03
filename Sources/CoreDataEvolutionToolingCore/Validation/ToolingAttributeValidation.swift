@_exported import CoreDataEvolutionSchemaSupport
import Foundation
import SwiftParser
import SwiftSyntax

/// Parses the same literal subset as @Attribute without executing developer-authored Swift.
/// Failures are retained in source IR so invalid/dynamic arguments never look like absent rules.
func toolingAttributeValidation(
  _ attribute: AttributeSyntax
) -> (rules: CDAttributeValidationRules, issue: String?) {
  var arguments: [String: String] = [:]
  var regex: String?
  do {
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
    return (try .parse(arguments: arguments, decodedRegex: regex), nil)
  } catch { return (.init(), error.localizedDescription) }
}
