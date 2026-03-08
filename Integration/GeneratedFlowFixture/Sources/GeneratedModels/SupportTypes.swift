import CoreDataEvolution
import Foundation

public enum FlowTaskStatus: String, Sendable {
  case backlog
  case review
  case done
}

public struct FlowTaskConfig: Codable, Sendable, Equatable {
  public var owner: String
  public var retryCount: Int
  public var isFlagged: Bool

  public init(owner: String, retryCount: Int, isFlagged: Bool) {
    self.owner = owner
    self.retryCount = retryCount
    self.isFlagged = isFlagged
  }
}

@Composition
public struct FlowPoint: Sendable, Equatable {
  @CompositionField(persistentName: "lat")
  public var latitude: Double = 0

  @CompositionField(persistentName: "lng")
  public var longitude: Double? = nil

  public init(latitude: Double = 0, longitude: Double? = nil) {
    self.latitude = latitude
    self.longitude = longitude
  }
}

public final class FlowStringListTransformer: ValueTransformer {
  public override class func transformedValueClass() -> AnyClass {
    NSString.self
  }

  public override class func allowsReverseTransformation() -> Bool {
    true
  }

  public override func transformedValue(_ value: Any?) -> Any? {
    guard let strings = value as? [String] else { return nil }
    return strings.joined(separator: "|")
  }

  public override func reverseTransformedValue(_ value: Any?) -> Any? {
    let raw: String?
    switch value {
    case let stringValue as String:
      raw = stringValue
    case let nsStringValue as NSString:
      raw = nsStringValue as String
    default:
      raw = nil
    }

    guard let raw else { return nil }
    if raw.isEmpty {
      return []
    }
    return raw.split(separator: "|").map(String.init)
  }

  public static func register() {
    ValueTransformer.setValueTransformer(
      FlowStringListTransformer(),
      forName: NSValueTransformerName("FlowStringListTransformer")
    )
  }
}
