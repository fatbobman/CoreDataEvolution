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
import Foundation

final class TestStack {
  @MainActor var viewContext: NSManagedObjectContext {
    container.viewContext
  }

  static let model: NSManagedObjectModel = {
    let model = NSManagedObjectModel()
    let itemEntity = NSEntityDescription()
    itemEntity.name = "Item"
    itemEntity.managedObjectClassName = NSStringFromClass(Item.self)

    let timestampAttribute = NSAttributeDescription()
    timestampAttribute.name = "timestamp"
    timestampAttribute.attributeType = .dateAttributeType
    timestampAttribute.isOptional = true

    itemEntity.properties = [timestampAttribute]
    model.entities = [itemEntity]
    return model
  }()

  let container: NSPersistentContainer

  init(
    testName: String = "",
    fileID: String = #fileID,
    function: String = #function
  ) {
    container = NSPersistentContainer.makeTest(
      model: Self.model,
      testName: testName,
      fileID: fileID,
      function: function
    )
    container.viewContext.automaticallyMergesChangesFromParent = true
  }
}
