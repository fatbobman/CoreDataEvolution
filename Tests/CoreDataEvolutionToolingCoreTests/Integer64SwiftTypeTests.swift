@preconcurrency import CoreData
import CoreDataEvolutionToolingCore
import Foundation
import Testing

@Suite("Integer 64 Swift representation")
struct Integer64SwiftTypeTests {
  private func config(_ generate: String = "", _ validate: String = "") throws
    -> ToolingConfigTemplate
  {
    try loadToolingConfigTemplate(
      from: Data(
        """
        {"$schemaVersion":1,
         "generate":{"modelPath":"App.xcdatamodeld","outputDir":"Generated","moduleName":"App"\(generate)},
         "validate":{"modelPath":"App.xcdatamodeld","sourceDir":"Generated","moduleName":"App"\(validate)}}
        """.utf8))
  }

  @Test("config defaults, legacy mapping, shared policy and CLI override")
  func configurationResolution() throws {
    let defaults = try config()
    #expect(
      try GenerateRequest(config: #require(defaults.generate)).typeMappings[
        coreDataType: "Integer 64"]?.swiftType == "Int64")
    let explicit = try config(
      #", "integer64SwiftType":"Int""#,
      #", "integer64SwiftType":"Int""#)
    let generate = try GenerateRequest(config: #require(explicit.generate))
    let validate = try ValidateRequest(config: #require(explicit.validate))
    #expect(generate.integer64SwiftType == .int)
    #expect(validate.integer64SwiftType == .int)
    #expect(generate.typeMappings[coreDataType: "Integer 64"]?.swiftType == "Int")
    #expect(validate.typeMappings == generate.typeMappings)
    #expect(
      InspectRequest(config: try #require(explicit.generate)).typeMappings == generate.typeMappings)
    var overrides = GenerateRequestOverrides()
    overrides.integer64SwiftType = .int64
    #expect(
      try GenerateRequest(config: #require(explicit.generate), overrides: overrides).typeMappings[
        coreDataType: "Integer 64"]?.swiftType == "Int64")
    var validationOverrides = ValidateRequestOverrides()
    validationOverrides.integer64SwiftType = .int64
    #expect(
      try ValidateRequest(config: #require(explicit.validate), overrides: validationOverrides)
        .integer64SwiftType == .int64)
    let legacy = try config(#", "typeMappings":{"Integer 64":{"swiftType":"Int"}}"#)
    let legacyRequest = try GenerateRequest(config: #require(legacy.generate))
    #expect(legacyRequest.integer64SwiftType == nil)
    #expect(legacyRequest.typeMappings[coreDataType: "Integer 64"]?.swiftType == "Int")
  }

  @Test("invalid policies and contradictory legacy mappings are rejected")
  func invalidConfiguration() throws {
    #expect(throws: (any Error).self) { try config(#", "integer64SwiftType":"Int32""#) }
    for section in [true, false] {
      let conflict =
        #", "integer64SwiftType":"Int", "typeMappings":{"Integer 64":{"swiftType":"Int64"}}"#
      #expect(throws: (any Error).self) {
        try config(section ? conflict : "", section ? "" : conflict)
      }
    }
    let matching = try config(
      #", "integer64SwiftType":"Int", "typeMappings":{"Integer 64":{"swiftType":"Int"}}"#)
    #expect(try GenerateRequest(config: #require(matching.generate)).integer64SwiftType == .int)
  }

  @Test("scaffolds contain one editable Integer 64 setting")
  func scaffoldRoundTrip() throws {
    let full = makeDefaultConfigTemplate(preset: .full)
    let data = try encodeToolingJSON(full)
    var json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    for section in ["generate", "validate"] {
      var settings = try #require(json[section] as? [String: Any])
      let mappings = try #require(settings["typeMappings"] as? [String: Any])
      #expect(mappings["Integer 64"] == nil)
      settings["integer64SwiftType"] = "Int"
      json[section] = settings
    }
    let updated = try loadToolingConfigTemplate(from: JSONSerialization.data(withJSONObject: json))
    #expect(try GenerateRequest(config: #require(updated.generate)).integer64SwiftType == .int)
    #expect(try ValidateRequest(config: #require(updated.validate)).integer64SwiftType == .int)
  }

  @Test(
    "only Integer 64 conformance accepts the legacy representation",
    arguments: ["Int64", "Int"], [false, true])
  func comparisonMatrix(policy: String, optional: Bool) throws {
    let model = NSManagedObjectModel()
    let entity = NSEntityDescription()
    entity.name = "Item"
    entity.managedObjectClassName = "Item"
    entity.properties = [
      ("wide", NSAttributeType.integer64AttributeType),
      ("medium", .integer32AttributeType), ("small", .integer16AttributeType),
    ].map { name, type in
      let attribute = NSAttributeDescription()
      attribute.name = name
      attribute.attributeType = type
      attribute.isOptional = optional
      return attribute
    }
    model.entities = [entity]
    let loaded = ToolingLoadedModel(
      model: model,
      resolvedInput: .init(
        originalURL: URL(fileURLWithPath: "/App.xcdatamodeld"),
        selectedSourceURL: URL(fileURLWithPath: "/App.xcdatamodeld/V1.xcdatamodel"),
        compiledModelURL: URL(fileURLWithPath: "/App.momd"), kind: .xcdatamodeld,
        selectedVersionName: "V1.xcdatamodel"))
    let template = try #require(
      config(
        ", \"integer64SwiftType\":\"\(policy)\""
      ).generate)
    let request = try GenerateRequest(config: template)
    let ir = ToolingIRBuilder.build(from: loaded, request: .init(generateRequest: request)).modelIR
    let sources = try ToolingSourceRenderer.renderSources(from: ir, moduleName: "App", header: nil)
    let generated = try #require(sources.first).contents
    #expect(generated.contains("var wide: \(policy)\(optional ? "?" : "")"))
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("Item.swift")
    for level in [ToolingValidationLevel.conformance, .exact] {
      for sourceType in ["Int", "Int64"] {
        let source = generated.replacingOccurrences(
          of: "var wide: \(policy)", with: "var wide: \(sourceType)")
        try source.write(to: file, atomically: true, encoding: .utf8)
        let diagnostics = ToolingValidateComparator.compareQuick(
          expected: ir, actual: try ToolingSourceParser.parse(sourceDirectory: directory.path),
          level: level, integer64SwiftType: request.integer64SwiftType)
        let accepted = sourceType == policy || (policy == "Int" && level == .conformance)
        #expect(diagnostics.filter { $0.severity == .error }.isEmpty == accepted)
      }
    }
    for field in ["medium: Int32", "small: Int16"] {
      try generated.replacingOccurrences(
        of: field, with: field.components(separatedBy: ":")[0] + ": Int"
      )
      .write(to: file, atomically: true, encoding: .utf8)
      let diagnostics = ToolingValidateComparator.compareQuick(
        expected: ir, actual: try ToolingSourceParser.parse(sourceDirectory: directory.path),
        level: .conformance, integer64SwiftType: .int)
      #expect(diagnostics.contains { $0.message.contains("type mismatch") })
    }
    if optional {
      try generated.replacingOccurrences(of: "var wide: \(policy)?", with: "var wide: Int64")
        .write(to: file, atomically: true, encoding: .utf8)
      let diagnostics = ToolingValidateComparator.compareQuick(
        expected: ir, actual: try ToolingSourceParser.parse(sourceDirectory: directory.path),
        level: .conformance, integer64SwiftType: .int)
      #expect(diagnostics.contains { $0.message.contains("type mismatch") })
    }
  }
}
