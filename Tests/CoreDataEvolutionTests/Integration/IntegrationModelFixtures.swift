//
//  ------------------------------------------------
//  Original project: CoreDataEvolution
//  Created on 2026/3/5 by Fatbobman(东坡肘子)
//  X: @fatbobman
//  Mastodon: @fatbobman@mastodon.social
//  GitHub: @fatbobman
//  Blog: https://fatbobman.com
//  ------------------------------------------------
//  Copyright © 2024-present Fatbobman. All rights reserved.

@preconcurrency import CoreData
import CoreDataEvolution
import Foundation

enum CDEItemStatus: String, Sendable {
  case active
  case archived
}

struct CDEItemConfig: Codable, Equatable, Sendable {
  var isPinned: Bool
  var note: String
}

@Composition
struct CDEItemLocation: Equatable, Sendable {
  var x: Double
  var y: Double?
}

final class CDEStringListTransformer: ValueTransformer {
  override class func transformedValueClass() -> AnyClass {
    NSString.self
  }

  override class func allowsReverseTransformation() -> Bool {
    true
  }

  override func transformedValue(_ value: Any?) -> Any? {
    guard let strings = value as? [String] else { return nil }
    return strings.joined(separator: "|")
  }

  override func reverseTransformedValue(_ value: Any?) -> Any? {
    guard let raw = value as? String else { return nil }
    if raw.isEmpty {
      return []
    }
    return raw.split(separator: "|").map(String.init)
  }
}

@objc(CDETag)
@PersistentModel
final class CDETag: NSManagedObject {
  var id: UUID? = nil
  var label: String = ""
  @Relationship(inverse: "tag", deleteRule: .nullify)
  var items: Set<CDEItem>
}

@objc(CDEItem)
@PersistentModel
final class CDEItem: NSManagedObject {
  var id: UUID? = nil
  @Attribute(persistentName: "name")
  var title: String = ""
  var priority: Int16 = 0
  @Attribute(persistentName: "status_raw", storageMethod: .raw)
  var status: CDEItemStatus? = nil
  @Attribute(persistentName: "config_blob", storageMethod: .codable)
  var config: CDEItemConfig? = nil
  @Attribute(storageMethod: .composition)
  var location: CDEItemLocation? = nil
  @Attribute(
    persistentName: "keywords_payload", storageMethod: .transformed(CDEStringListTransformer.self))
  var keywords: [String]? = nil
  @Relationship(inverse: "items", deleteRule: .nullify)
  var tag: CDETag?
}
