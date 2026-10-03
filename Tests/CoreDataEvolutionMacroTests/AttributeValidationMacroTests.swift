import Testing

@Suite("Attribute validation macros")
struct AttributeValidationMacroTests {
  @Test func validationSnapshot() throws {
    try MacroTestSupport.assertExpansionSnapshot(fixtureName: "AttributeValidation")
  }

  @Test(arguments: [
    ("min: 5, max: 1", "Int?", "`min` must not exceed `max`"),
    ("minLength: -1", "String?", "non-negative integer"),
    ("minLength: 1.0", "String?", "non-negative integer"),
    ("min: 0.123456789012345678901234567890123456789123456789", "Decimal?", "numeric literal"),
    ("min: 1e-200", "Double?", "numeric literal"),
    ("minLength: 5, maxLength: 1", "String?", "`minLength` must not exceed `maxLength`"),
    ("regex: /abc/", "String?", "Swift Regex literals are not supported"),
    (#"regex: "[""#, "String?", "Invalid ICU"),
    (#"regex: "abc""#, "Int?", "only support String"),
    ("min: 1", "String?", "only support numeric"),
    ("minDate: Date()", "Date?", "dynamic dates cannot be tested faithfully"),
    (
      "minDate: Date(timeIntervalSince1970: 2), maxDate: Date(timeIntervalSince1970: 1)", "Date?",
      "`minDate` must not exceed `maxDate`"
    ),
    ("min: lowerBound", "Int?", "numeric literal"),
    (
      #"regex: "abc", storageMethod: .raw"#, "Status?", "custom storage cannot be tested faithfully"
    ),
    ("min: 0, min: 1", "Int?", "Duplicate"),
  ])
  func invalidRules(arguments: String, type: String, diagnostic: String) throws {
    let result = try MacroTestSupport.expand(
      source: """
        @Attribute(\(arguments))
        var value: \(type)
        """)
    #expect(result.diagnostics.contains { $0.contains(diagnostic) })
  }

  @Test func decodedPatternsProduceIdenticalMetadata() throws {
    let escaped = try MacroTestSupport.expand(
      source: #"""
        @objc(Sample)
        @PersistentModel
        final class Sample: NSManagedObject {
          @Attribute(regex: ".*\\S.*") var name: String?
        }
        """#)
    let raw = try MacroTestSupport.expand(
      source: ##"""
        @objc(Sample)
        @PersistentModel
        final class Sample: NSManagedObject {
          @Attribute(regex: #".*\S.*"#) var name: String?
        }
        """##)
    #expect(escaped.diagnostics.isEmpty)
    #expect(raw.diagnostics.isEmpty)
    #expect(escaped.formattedExpandedSource == raw.formattedExpandedSource)
  }
}
