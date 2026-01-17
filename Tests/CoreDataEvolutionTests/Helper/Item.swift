//
//  ------------------------------------------------
//  Original project: CoreDataEvolution
//  Created on 2024/8/22 by Fatbobman(东坡肘子)
//  X: @fatbobman
//  Mastodon: @fatbobman@mastodon.social
//  GitHub: @fatbobman
//  Blog: https://fatbobman.com
//  ------------------------------------------------
//  Copyright © 2024-present Fatbobman. All rights reserved.

@preconcurrency import CoreData

@objc(Item)
public class Item: NSManagedObject {}
extension Item {
  @nonobjc public class func fetchRequest() -> NSFetchRequest<Item> {
    return NSFetchRequest<Item>(entityName: "Item")
  }

  @NSManaged public var timestamp: Date?
}
extension Item {
  static let fetchAll: NSFetchRequest<Item> = {
    let request = NSFetchRequest<Item>(entityName: "Item")
    request.sortDescriptors = [.init(key: "timestamp", ascending: true)]
    return request
  }()
}
