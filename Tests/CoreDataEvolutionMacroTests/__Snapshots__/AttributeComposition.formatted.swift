import CoreDataEvolution
struct Magnitude {
  var richter: Double

  static let __cdCompositionFieldTable: [String: CoreDataEvolution.CDCompositionFieldMeta] = [
    "richter": .init(swiftPath: ["richter"], persistentPath: ["richter"])
  ]

  static let __cdFieldTable: [String: CoreDataEvolution.CDFieldMeta] = {
    CoreDataEvolution.CDCompositionTableBuilder.makeModelFieldEntries(
      modelSwiftPathPrefix: [],
      modelPersistentPathPrefix: [],
      composition: Self.self
    )
  }()

  enum Paths {
  static let richter = CoreDataEvolution.CDPath<Magnitude, Double>(
    swiftPath: ["richter"],
    persistentPath: ["richter"]
  )
  }

  struct PathRoot: Sendable {
  var richter: CoreDataEvolution.CDPath<Magnitude, Double> {
    Paths.richter
  }
  }

  static var path: PathRoot {
    .init()
  }

  static let __cdRuntimeCompositionFields: [CoreDataEvolution.CDRuntimeCompositionFieldSchema] = [
  .init(
    persistentName: "richter",
    swiftTypeName: "Double",
    primitiveType: .double,
    isOptional: false,
    defaultValueExpression: nil
  )
  ]

  static func __cdDecodeComposition(from dictionary: [String: Any]) -> Self? {
    guard let richter = dictionary["richter"] as? Double else {
      return nil
    }
    return .init(richter: richter)
  }

  var __cdEncodeComposition: [String: Any] {
    var dictionary: [String: Any] = [:]
    dictionary["richter"] = richter
    return dictionary
  }
}

struct Item {
  var magnitude: Magnitude? {
    get {
      guard let dictionary = value(forKey: "magnitude") as? [String: Any] else {
        return nil
      }
      return Magnitude.__cdDecodeComposition(from: dictionary)
    }
    set {
      setValue(newValue?.__cdEncodeComposition, forKey: "magnitude")
    }
  }

  private static let __cd_attribute_validate_magnitude_nonrelationship: Void = CoreDataEvolution._CDAttributeMacroValidation.requireNonRelationship(Magnitude?.self)

  private static let __cd_attribute_validate_magnitude_composition: Void = CoreDataEvolution._CDAttributeMacroValidation.requireComposition(Magnitude.self)
}

extension Magnitude: CoreDataEvolution.CDCompositionPathProviding, CoreDataEvolution.CDCompositionValueCodable, CoreDataEvolution.CoreDataPathDSLProviding {
}