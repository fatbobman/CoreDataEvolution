@preconcurrency import CoreData
@preconcurrency import CoreDataEvolution
import Foundation
import Testing

@objc(AttributeValidationSample)
@PersistentModel
final class AttributeValidationSample: NSManagedObject {
  var unrestricted: String?
  @Attribute(persistentName: "name", minLength: 1, maxLength: 8, regex: #".*\S.*"#)
  var title: String?

  @Attribute(min: 0, max: 255)
  var count: Int64?

  @Attribute(
    minDate: Date(timeIntervalSinceReferenceDate: 0),
    maxDate: Date(timeIntervalSinceReferenceDate: 120))
  var timestamp: Date?

  @Attribute(min: 9_007_199_254_740_993, max: 9_223_372_036_854_775_807)
  var precise: Int64?

  @Attribute(min: 0, max: 1)
  var amount: Decimal?
}

private struct ValidationOutcome: Sendable, Equatable {
  let codes: [Int]
  let keys: [String]
}

@NSModelActor
private actor AttributeValidationHandler {
  func check(
    title: String? = "valid",
    count: Int64? = 100,
    time: Double? = 60,
    precise: Int64? = 9_007_199_254_740_993,
    amount: Decimal? = 0.125,
    update: Bool = false
  ) throws -> ValidationOutcome {
    defer { modelContext.rollback() }
    let entity = try #require(
      modelContext.persistentStoreCoordinator?.managedObjectModel.entitiesByName[
        "AttributeValidationSample"])
    let item = AttributeValidationSample(entity: entity, insertInto: modelContext)
    item.title = "valid"
    if update { try modelContext.save() }
    item.title = title
    item.count = count
    item.timestamp = time.map { Date(timeIntervalSinceReferenceDate: $0) }
    item.precise = precise
    item.amount = amount
    do {
      try modelContext.save()
      return .init(codes: [], keys: [])
    } catch {
      func leaves(_ error: NSError) -> [NSError] {
        // Also accept the dictionary key emitted by Core Data when an SDK overlay exposes a
        // differently spelled NSDetailedErrorsKey constant.
        let detailsValue =
          error.userInfo[CoreData.NSDetailedErrorsKey] ?? error.userInfo["NSDetailedErrors"]
        if let details = detailsValue as? [NSError] {
          return details.flatMap(leaves)
        }
        return [error]
      }
      let errors = leaves(error as NSError)
      return .init(
        codes: errors.map(\.code).sorted(),
        keys: errors.compactMap {
          ($0.userInfo[CoreData.NSValidationKeyErrorKey] ?? $0.userInfo["NSValidationErrorKey"])
            as? String
        }.sorted()
      )
    }
  }
}

private enum AttributeValidationModels {
  static let runtime = try! NSManagedObjectModel.makeRuntimeModel(AttributeValidationSample.self)
  static let compiled: NSManagedObjectModel = {
    do {
      let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
      let output = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        .appendingPathComponent("AttributeValidation.mom")
      defer { try? FileManager.default.removeItem(at: output.deletingLastPathComponent()) }
      let process = Process()
      process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
      process.arguments = [
        "bash", root.appendingPathComponent("Scripts/compile-integration-model.sh").path,
        root.appendingPathComponent("Models/Validation/AttributeValidation.xcdatamodel").path,
        output.path,
      ]
      let pipe = Pipe()
      process.standardOutput = pipe
      process.standardError = pipe
      try process.run()
      let data = pipe.fileHandleForReading.readDataToEndOfFile()
      process.waitUntilExit()
      guard process.terminationStatus == 0,
        let model = NSManagedObjectModel(contentsOf: output)
      else {
        throw NSError(
          domain: "ValidationModel", code: 1,
          userInfo: [NSLocalizedDescriptionKey: String(decoding: data, as: UTF8.self)])
      }
      return model
    } catch { preconditionFailure("Could not compile validation model: \(error)") }
  }()
}

@Suite("Attribute validation runtime and compiled models", .serialized)
struct AttributeValidationTests {
  @Test func schemaMatchesCompiledModel() throws {
    let runtime = try #require(
      AttributeValidationModels.runtime.entitiesByName["AttributeValidationSample"])
    let compiled = try #require(
      AttributeValidationModels.compiled.entitiesByName["AttributeValidationSample"])
    for (key, attribute) in compiled.attributesByName {
      let generated = try #require(runtime.attributesByName[key])
      #expect(
        try CDAttributeValidationRules.read(from: generated)
          == CDAttributeValidationRules.read(from: attribute))
      #expect(
        NSArray(array: generated.validationWarnings).isEqual(to: attribute.validationWarnings))
    }
  }

  @Test func savesMatchRealModelIncludingErrorCodesAndPersistentKeys() async throws {
    let runtimeContainer = try NSPersistentContainer.makeTest(
      model: AttributeValidationModels.runtime, testName: "AttributeValidationRuntime")
    let compiledContainer = try NSPersistentContainer.makeTest(
      model: AttributeValidationModels.compiled, testName: "AttributeValidationCompiled")
    let runtime = AttributeValidationHandler(container: runtimeContainer)
    let compiled = AttributeValidationHandler(container: compiledContainer)
    for update in [false, true] {
      for value: Int64 in [-1, 0, 255, 256] {
        let actual = try await runtime.check(count: value, update: update)
        #expect(actual == (try await compiled.check(count: value, update: update)))
        #expect(
          actual.codes
            == (value == -1
              ? [NSValidationNumberTooSmallError]
              : value == 256 ? [NSValidationNumberTooLargeError] : []))
      }
      for title in ["", " ", "\u{3000}", "abc", "12345678", "123456789", "e\u{301}", "👨‍👩‍👧‍👦"] {
        let actual = try await runtime.check(title: title, update: update)
        #expect(actual == (try await compiled.check(title: title, update: update)))
        if title.isEmpty {
          #expect(
            actual.codes == [
              NSValidationStringTooShortError, NSValidationStringPatternMatchingError,
            ])
        } else if title == " " || title == "\u{3000}" {
          #expect(actual.codes == [NSValidationStringPatternMatchingError])
        } else if title == "123456789" || title == "👨‍👩‍👧‍👦" {
          #expect(actual.codes == [NSValidationStringTooLongError])
        } else {
          #expect(actual.codes.isEmpty)
        }
      }
      for time in [-1.0, 0, 120, 121] {
        let actual = try await runtime.check(time: time, update: update)
        #expect(actual == (try await compiled.check(time: time, update: update)))
        #expect(
          actual.codes
            == (time == -1
              ? [NSValidationDateTooSoonError] : time == 121 ? [NSValidationDateTooLateError] : []))
      }
      for precise: Int64 in [9_007_199_254_740_992, 9_007_199_254_740_993, Int64.max] {
        let actual = try await runtime.check(precise: precise, update: update)
        #expect(actual == (try await compiled.check(precise: precise, update: update)))
        #expect(
          actual.codes == (precise < 9_007_199_254_740_993 ? [NSValidationNumberTooSmallError] : [])
        )
      }
      for amount: Decimal in [-0.001, 0, 0.125, 1, 1.001] {
        #expect(
          try await runtime.check(amount: amount, update: update)
            == compiled.check(amount: amount, update: update))
      }
    }
    let nilResult = try await runtime.check(
      title: nil, count: nil, time: nil, precise: nil, amount: nil)
    #expect(nilResult.codes.isEmpty)
    #expect(
      nilResult
        == (try await compiled.check(title: nil, count: nil, time: nil, precise: nil, amount: nil)))
    let invalid = try await runtime.check(title: "", count: -1, time: -1)
    #expect(invalid == (try await compiled.check(title: "", count: -1, time: -1)))
    #expect(invalid.keys.contains("name"))
    #expect(!invalid.keys.contains("title"))
    #expect(
      invalid.codes == [
        NSValidationNumberTooSmallError, NSValidationDateTooSoonError,
        NSValidationStringTooShortError, NSValidationStringPatternMatchingError,
      ])
  }

  @Test func unsupportedManualSchemaRulesAreReported() throws {
    let attribute = NSAttributeDescription()
    attribute.name = "title"
    attribute.attributeType = .stringAttributeType
    #expect(throws: CDAttributeValidationError.self) {
      try CDAttributeValidationRules(minimumValue: "1").apply(to: attribute)
    }
    attribute.setValidationPredicates(
      [NSPredicate(format: "SELF BEGINSWITH %@", "A")], withValidationWarnings: ["Custom"])
    #expect(throws: CDAttributeValidationError.self) {
      try CDAttributeValidationRules.read(from: attribute)
    }
    attribute.setValidationPredicates(
      [NSPredicate(format: "length >= 1")], withValidationWarnings: ["Custom message"])
    #expect(throws: CDAttributeValidationError.self) {
      try CDAttributeValidationRules.read(from: attribute)
    }
    #expect(throws: CDAttributeValidationError.self) {
      try CDAttributeValidationRules(minimumValue: "1suffix").validate()
    }
  }
}
