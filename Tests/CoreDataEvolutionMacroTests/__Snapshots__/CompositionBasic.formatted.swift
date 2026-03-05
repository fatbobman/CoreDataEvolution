import CoreDataEvolution

public struct Location {
  public var x: Double
  public var y: Double?
  public var label: String
  public var webpage: URL?

  public static let __cdCompositionFieldTable: [String: CoreDataEvolution.CDCompositionFieldMeta] =
    [
      "x": .init(swiftPath: ["x"], persistentPath: ["x"]),
      "y": .init(swiftPath: ["y"], persistentPath: ["y"]),
      "label": .init(swiftPath: ["label"], persistentPath: ["label"]),
      "webpage": .init(swiftPath: ["webpage"], persistentPath: ["webpage"]),
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

extension Location: CoreDataEvolution.CDCompositionPathProviding, CoreDataEvolution
    .CDCompositionValueCodable
{
}
