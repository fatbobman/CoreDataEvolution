import CoreDataEvolution
public struct Location {
  public var x: Double
  public var y: Double?
  public var label: String
  public var webpage: URL?

  public static let __cdCompositionFieldTable: [String: CoreDataEvolution.CDCompositionFieldMeta] = [
    "x": .init(swiftPath: ["x"], persistentPath: ["x"]),
    "y": .init(swiftPath: ["y"], persistentPath: ["y"]),
    "label": .init(swiftPath: ["label"], persistentPath: ["label"]),
    "webpage": .init(swiftPath: ["webpage"], persistentPath: ["webpage"])
  ]

  public static let __cdFieldTable: [String: CoreDataEvolution.CDFieldMeta] = {
    CoreDataEvolution.CDCompositionTableBuilder.makeModelFieldEntries(
      modelSwiftPathPrefix: [],
      modelPersistentPathPrefix: [],
      composition: Self.self
    )
  }()

  public enum Paths {
    public static let x = CoreDataEvolution.CDPath<Location, Double>(
      swiftPath: ["x"],
      persistentPath: ["x"]
    )

    public static let y = CoreDataEvolution.CDPath<Location, Double?>(
      swiftPath: ["y"],
      persistentPath: ["y"]
    )

    public static let label = CoreDataEvolution.CDPath<Location, String>(
      swiftPath: ["label"],
      persistentPath: ["label"]
    )

    public static let webpage = CoreDataEvolution.CDPath<Location, URL?>(
      swiftPath: ["webpage"],
      persistentPath: ["webpage"]
    )
  }

  public struct PathRoot: Sendable {
    public var x: CoreDataEvolution.CDPath<Location, Double> {
      Paths.x
    }

    public var y: CoreDataEvolution.CDPath<Location, Double?> {
      Paths.y
    }

    public var label: CoreDataEvolution.CDPath<Location, String> {
      Paths.label
    }

    public var webpage: CoreDataEvolution.CDPath<Location, URL?> {
      Paths.webpage
    }
  }

  public static var path: PathRoot {
    .init()
  }

  public static let __cdRuntimeCompositionFields: [CoreDataEvolution.CDRuntimeCompositionFieldSchema] = [
    .init(
      persistentName: "x",
      swiftTypeName: "Double",
      primitiveType: .double,
      isOptional: false,
      defaultValueExpression: nil
    ),
    .init(
      persistentName: "y",
      swiftTypeName: "Double?",
      primitiveType: .double,
      isOptional: true,
      defaultValueExpression: "nil"
    ),
    .init(
      persistentName: "label",
      swiftTypeName: "String",
      primitiveType: .string,
      isOptional: false,
      defaultValueExpression: nil
    ),
    .init(
      persistentName: "webpage",
      swiftTypeName: "URL?",
      primitiveType: .url,
      isOptional: true,
      defaultValueExpression: "nil"
    )
  ]

  public static func __cdDecodeComposition(from dictionary: [String: Any]) -> Self? {
    guard let x = dictionary["x"] as? Double else {
      return nil
    }
    let y = dictionary["y"] as? Double
    guard let label = dictionary["label"] as? String else {
      return nil
    }
    let webpage = dictionary["webpage"] as? URL
    return .init(x: x, y: y, label: label, webpage: webpage)
  }

  public var __cdEncodeComposition: [String: Any] {
    var dictionary: [String: Any] = [:]
    dictionary["x"] = x
    if let y {
      dictionary["y"] = y
    }
    dictionary["label"] = label
    if let webpage {
      dictionary["webpage"] = webpage
    }
    return dictionary
  }
}

extension Location: CoreDataEvolution.CDCompositionPathProviding, CoreDataEvolution.CDCompositionValueCodable, CoreDataEvolution.CoreDataPathDSLProviding {
}