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
    NSData.self
  }

  public override class func allowsReverseTransformation() -> Bool {
    true
  }

  public override func transformedValue(_ value: Any?) -> Any? {
    guard let strings = value as? [String] else { return nil }
    return try? NSKeyedArchiver.archivedData(withRootObject: strings, requiringSecureCoding: true)
  }

  public override func reverseTransformedValue(_ value: Any?) -> Any? {
    guard let data = value as? Data else { return nil }
    return try? NSKeyedUnarchiver.unarchivedObject(
      ofClasses: [NSArray.self, NSString.self], from: data) as? [String]
  }

  public static func register() {
    ValueTransformer.setValueTransformer(
      FlowStringListTransformer(),
      forName: NSValueTransformerName("FlowStringListTransformer")
    )
  }
}
