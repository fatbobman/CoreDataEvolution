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

@objc(CDETag)
@PersistentModel
final class CDETag: NSManagedObject {
  var id: UUID? = nil
  var label: String = ""
  var items: Set<CDEItem>
}

@objc(CDEItem)
@PersistentModel
final class CDEItem: NSManagedObject {
  var id: UUID? = nil
  var name: String = ""
  var priority: Int16 = 0
  var tag: CDETag?
}
