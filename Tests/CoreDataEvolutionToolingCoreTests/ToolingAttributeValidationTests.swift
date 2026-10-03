@preconcurrency import CoreData
import CoreDataEvolutionToolingCore
import Foundation
import Testing

private struct AttributeValidationToolFixture {
  let root: URL
  let model: URL
  let sources: URL
  let rules = ToolingAttributeRules(entities: [
    "AttributeValidationSample": ["name": .init(swiftName: "title")]
  ])

  init(pattern: String? = nil) throws {
    root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    sources = root.appendingPathComponent("Sources")
    let sourceModel = try findToolingRepositoryRoot().appendingPathComponent(
      "Models/Validation/AttributeValidation.xcdatamodel")
    if let pattern {
      try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
      model = root.appendingPathComponent("AttributeValidation.xcdatamodel")
      try FileManager.default.copyItem(at: sourceModel, to: model)
      let contents = model.appendingPathComponent("contents")
      let xml = try String(contentsOf: contents, encoding: .utf8)
      try xml.replacingOccurrences(
        of: #"regularExpressionString=".*\S.*""#,
        with: "regularExpressionString=\"\(pattern)\""
      ).write(to: contents, atomically: true, encoding: .utf8)
    } else {
      model = sourceModel
    }
    _ = try GenerateService.run(
      .init(
        modelPath: model.path, modelVersion: nil, momcBin: nil,
        outputDir: sources.path, moduleName: "ValidationModels",
        typeMappings: makeDefaultToolingTypeMappings(), attributeRules: rules,
        accessLevel: .internal, singleFile: false, splitByEntity: true,
        overwrite: .none, cleanStale: false, dryRun: false, format: .none,
        headerTemplate: nil, generateInit: false,
        defaultDecodeFailurePolicy: .fallbackToDefaultValue
      ))
  }

  var file: URL {
    sources.appendingPathComponent("AttributeValidationSample+CoreDataEvolution.swift")
  }

  func validate(_ level: ToolingValidationLevel = .conformance) throws -> ValidateResult {
    try ValidateService.run(
      .init(
        modelPath: model.path, modelVersion: nil, momcBin: nil,
        sourceDir: sources.path, moduleName: "ValidationModels",
        typeMappings: makeDefaultToolingTypeMappings(), attributeRules: rules,
        accessLevel: .internal, singleFile: false, splitByEntity: true,
        headerTemplate: nil, generateInit: false,
        defaultDecodeFailurePolicy: .fallbackToDefaultValue,
        include: ["*.swift"], exclude: [], level: level, report: .text,
        failOnWarning: false, maxIssues: 100
      ))
  }

  func replace(_ old: String, with new: String) throws {
    let source = try String(contentsOf: file, encoding: .utf8)
    #expect(source.contains(old))
    try source.replacingOccurrences(of: old, with: new).write(
      to: file, atomically: true, encoding: .utf8)
  }

  func cleanUp() { try? FileManager.default.removeItem(at: root) }
}

@Suite("Tooling attribute validation")
struct ToolingAttributeValidationTests {
  @Test func generatedValidationPassesBothLevels() throws {
    let fixture = try AttributeValidationToolFixture()
    defer { fixture.cleanUp() }
    for level: ToolingValidationLevel in [.conformance, .exact] {
      let result = try fixture.validate(level)
      #expect(result.errorCount == 0)
      #expect(result.warningCount == 0)
      let attributes = try #require(result.modelIR.entities.first).attributes
      #expect(
        attributes.first { $0.persistentName == "name" }?.validation.regularExpression == #".*\S.*"#
      )
      #expect(
        attributes.first { $0.persistentName == "precise" }?.validation.minimumValue
          == "9007199254740993")
      #expect(attributes.first { $0.persistentName == "timestamp" }?.validation.maximumDate == 120)
    }
  }

  @Test(arguments: [
    #"".*\\S.*""#,
    ##"#".*\S.*"#"##,
    #"".*\u{5c}S.*""#,
    "\"\"\"\n  .*\\\\S.*\n  \"\"\"",
  ])
  func equivalentStringSpellingsPassConformance(patternLiteral: String) throws {
    let fixture = try AttributeValidationToolFixture()
    defer { fixture.cleanUp() }
    try fixture.replace(#"regex: ".*\\S.*""#, with: "regex: \(patternLiteral)")
    #expect(try fixture.validate().errorCount == 0)
  }

  @Test(arguments: [
    (#"regex: ".*[^\\s].*""#, "attribute validation mismatch"),
    (#"regex: "(?i).*\\S.*""#, "attribute validation mismatch"),
    (#"regex: " .*\\S.*""#, "attribute validation mismatch"),
    (#"regex: "^.*\\S.*$""#, "attribute validation mismatch"),
    (#"regex: "[""#, "Invalid ICU"),
    ("regex: pattern", "string literal"),
    (#"regex: "\(pattern)""#, "string literal"),
    ("regex: /abc/", "Swift Regex literals"),
    ("regex: nil", "attribute validation mismatch"),
  ])
  func changedOrUnresolvedPatternsAreReported(replacement: String, expectedMessage: String) throws {
    let fixture = try AttributeValidationToolFixture()
    defer { fixture.cleanUp() }
    try fixture.replace(#"regex: ".*\\S.*""#, with: replacement)
    let result = try fixture.validate()
    #expect(result.errorCount > 0)
    #expect(
      result.diagnostics.contains {
        $0.message.contains(expectedMessage)
          && $0.message.contains("AttributeValidationSample.title")
      })
    #expect(
      result.diagnostics.filter { $0.message.contains("validation") }.allSatisfy { $0.fix == nil })
  }

  @Test func missingAndAdditionalRulesAreDetected() throws {
    let fixture = try AttributeValidationToolFixture()
    defer { fixture.cleanUp() }
    try fixture.replace("min: 0, max: 255", with: "min: 0, max: 256")
    try fixture.replace("minLength: 1, maxLength: 8, ", with: "")
    try fixture.replace("var unrestricted:", with: #"@Attribute(regex: "abc") var unrestricted:"#)
    let result = try fixture.validate()
    #expect(
      result.diagnostics.filter { $0.message.contains("attribute validation mismatch") }.count == 3)
  }

  @Test func exactModeStillDetectsLiteralSpellingDrift() throws {
    let fixture = try AttributeValidationToolFixture()
    defer { fixture.cleanUp() }
    try fixture.replace(#"regex: ".*\\S.*""#, with: ##"regex: #".*\S.*"#"##)
    #expect(try fixture.validate().errorCount == 0)
    #expect(try fixture.validate(.exact).errorCount > 0)
  }

  @Test func patternEqualityDoesNotNormalizeUnicode() {
    let composed = CDAttributeValidationRules(regularExpression: "\u{e9}")
    let decomposed = CDAttributeValidationRules(regularExpression: "e\u{301}")
    #expect(composed.regularExpression == decomposed.regularExpression)
    #expect(composed != decomposed)
  }

  @Test func unicodePatternChangesAreDetectedAgainstTheRealModel() throws {
    let fixture = try AttributeValidationToolFixture(pattern: "\u{e9}")
    defer { fixture.cleanUp() }
    #expect(try fixture.validate().errorCount == 0)
    try fixture.replace("regex: \"\u{e9}\"", with: #"regex: "e\u{301}""#)
    let result = try fixture.validate()
    #expect(result.diagnostics.contains { $0.message.contains("attribute validation mismatch") })
  }

  @Test func modelRulesOnCustomStorageAreRejectedBeforeWriting() throws {
    let model = try findToolingRepositoryRoot().appendingPathComponent(
      "Models/Validation/AttributeValidation.xcdatamodel")
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    #expect(throws: ToolingFailure.self) {
      try GenerateService.run(
        .init(
          modelPath: model.path, modelVersion: nil, momcBin: nil,
          outputDir: root.path, moduleName: "ValidationModels",
          typeMappings: makeDefaultToolingTypeMappings(),
          attributeRules: .init(entities: [
            "AttributeValidationSample": ["name": .init(swiftType: "Status", storageMethod: .raw)]
          ]),
          accessLevel: .internal, singleFile: false, splitByEntity: true,
          overwrite: .none, cleanStale: false, dryRun: false, format: .none,
          headerTemplate: nil, generateInit: false,
          defaultDecodeFailurePolicy: .fallbackToDefaultValue
        ))
    }
    #expect(!FileManager.default.fileExists(atPath: root.path))
  }

  @Test func annotationFixesDoNotRewriteChangedRules() throws {
    let fixture = try AttributeValidationToolFixture()
    defer { fixture.cleanUp() }
    try fixture.replace(#"persistentName: "name""#, with: #"persistentName: "other""#)
    try fixture.replace("minLength: 1", with: "minLength: 2")
    let result = try fixture.validate()
    let mismatch = result.diagnostics.first { $0.message.contains("persistentName mismatch") }
    #expect(mismatch != nil)
    #expect(mismatch?.fix == nil)
  }
}
