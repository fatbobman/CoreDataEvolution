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
