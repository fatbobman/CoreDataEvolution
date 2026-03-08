import CoreDataEvolution
public struct Coordinate {
  public var latitude: Double
  public var longitude: Double?

  public static let __cdCompositionFieldTable: [String: CoreDataEvolution.CDCompositionFieldMeta] = [
    "latitude": .init(swiftPath: ["latitude"], persistentPath: ["lat"]),
    "longitude": .init(swiftPath: ["longitude"], persistentPath: ["lng"])
  ]

  public static let __cdFieldTable: [String: CoreDataEvolution.CDFieldMeta] = {
    CoreDataEvolution.CDCompositionTableBuilder.makeModelFieldEntries(
      modelSwiftPathPrefix: [],
      modelPersistentPathPrefix: [],
      composition: Self.self
    )
  }()

  public enum Paths {
  public static let latitude = CoreDataEvolution.CDPath<Coordinate, Double>(
    swiftPath: ["latitude"],
    persistentPath: ["lat"]
  )

  public static let longitude = CoreDataEvolution.CDPath<Coordinate, Double?>(
    swiftPath: ["longitude"],
    persistentPath: ["lng"]
  )
  }

  public struct PathRoot: Sendable {
  public var latitude: CoreDataEvolution.CDPath<Coordinate, Double> {
    Paths.latitude
  }

  public var longitude: CoreDataEvolution.CDPath<Coordinate, Double?> {
    Paths.longitude
  }
  }

  public static var path: PathRoot {
    .init()
  }

  public static let __cdRuntimeCompositionFields: [CoreDataEvolution.CDRuntimeCompositionFieldSchema] = [
  .init(
    persistentName: "lat",
    swiftTypeName: "Double",
    primitiveType: .double,
    isOptional: false,
    defaultValueExpression: nil
  ),
  .init(
    persistentName: "lng",
    swiftTypeName: "Double?",
    primitiveType: .double,
    isOptional: true,
    defaultValueExpression: "nil"
  )
  ]

  public static func __cdDecodeComposition(from dictionary: [String: Any]) -> Self? {
    guard let latitude = dictionary["lat"] as? Double else { return nil }
    let longitude = dictionary["lng"] as? Double
    return .init(latitude: latitude, longitude: longitude)
  }

  public var __cdEncodeComposition: [String: Any] {
    var dictionary: [String: Any] = [:]
    dictionary["lat"] = latitude
    if let longitude { dictionary["lng"] = longitude }
    return dictionary
  }
}

extension Coordinate: CoreDataEvolution.CDCompositionPathProviding, CoreDataEvolution.CDCompositionValueCodable, CoreDataEvolution.CoreDataPathDSLProviding {
}