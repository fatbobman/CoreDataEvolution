//
//  ------------------------------------------------
//  Original project: CoreDataEvolution
//  Created on 2026/3/6 by Fatbobman(东坡肘子)
//  X: @fatbobman
//  Mastodon: @fatbobman@mastodon.social
//  GitHub: @fatbobman
//  Blog: https://fatbobman.com
//  ------------------------------------------------
//  Copyright © 2024-present Fatbobman. All rights reserved.

@preconcurrency import CoreData
import CoreDataEvolution
import Foundation
import Testing

@Composition
struct RuntimePoint {
  var x: Double = 0
  var y: Double? = nil
}

@objc(RuntimeSchemaItem)
@PersistentModel
final class RuntimeSchemaItem: NSManagedObject {
  @Attribute(.unique)
  var title: String = ""

  @Attribute(storageMethod: .composition)
  var point: RuntimePoint? = nil

  var tags: Set<RuntimeSchemaTag>
}

@objc(RuntimeSchemaTag)
@PersistentModel
final class RuntimeSchemaTag: NSManagedObject {
  var name: String = ""
  var items: Set<RuntimeSchemaItem>
}

@objc(RuntimeDocument)
@PersistentModel
final class RuntimeDocument: NSManagedObject {
  @Inverse(RuntimeUser.self, "authoredDocuments")
  var author: RuntimeUser?

  @Inverse(RuntimeUser.self, "editedDocuments")
  var editor: RuntimeUser?

  var title: String = ""
}

@objc(RuntimeUser)
@PersistentModel
final class RuntimeUser: NSManagedObject {
  @Inverse(RuntimeDocument.self, "author")
  var authoredDocuments: Set<RuntimeDocument>

  @Inverse(RuntimeDocument.self, "editor")
  var editedDocuments: Set<RuntimeDocument>

  var name: String = ""
}

struct RuntimeModelBuilderTests {
  @Test("runtime model builder assembles uniqueness and inferred inverses")
  func buildModelFromMacroGeneratedSchemas() throws {
    let model = try NSManagedObjectModel.makeRuntimeModel([
      RuntimeSchemaItem.self,
      RuntimeSchemaTag.self,
    ])

    let item = try #require(model.entitiesByName["RuntimeSchemaItem"])
    #expect(item.uniquenessConstraints as? [[String]] == [["title"]])

    let title = try #require(item.attributesByName["title"])
    #expect(title.attributeType == .stringAttributeType)
    #expect(title.isOptional == false)

    let point = try #require(item.attributesByName["point"])
    #expect(point.attributeType == .transformableAttributeType)

    let tags = try #require(item.relationshipsByName["tags"])
    #expect(tags.isToMany)
    #expect(tags.isOrdered == false)
    #expect(tags.destinationEntity?.name == "RuntimeSchemaTag")
    #expect(tags.inverseRelationship?.name == "items")
  }

  @Test("runtime model builder uses explicit inverse metadata for ambiguous relationships")
  func buildModelFromExplicitInverseHints() throws {
    let model = try NSManagedObjectModel.makeRuntimeModel([
      RuntimeDocument.self,
      RuntimeUser.self,
    ])

    let document = try #require(model.entitiesByName["RuntimeDocument"])
    let author = try #require(document.relationshipsByName["author"])
    let editor = try #require(document.relationshipsByName["editor"])

    #expect(author.inverseRelationship?.name == "authoredDocuments")
    #expect(editor.inverseRelationship?.name == "editedDocuments")
  }

  @MainActor
  @Test("runtime model builder supports sqlite-backed test containers")
  func runtimeModelBackedContainerRoundTrip() throws {
    let container = try NSPersistentContainer.makeRuntimeTest(
      modelTypes: [
        RuntimeSchemaItem.self,
        RuntimeSchemaTag.self,
      ],
      testName: "RuntimeModelBuilderRoundTrip"
    )

    let context = container.viewContext
    let tagEntity = try #require(
      NSEntityDescription.entity(forEntityName: "RuntimeSchemaTag", in: context)
    )
    let tag = RuntimeSchemaTag(entity: tagEntity, insertInto: context)
    tag.name = "swift"

    let itemEntity = try #require(
      NSEntityDescription.entity(forEntityName: "RuntimeSchemaItem", in: context)
    )
    let item = RuntimeSchemaItem(entity: itemEntity, insertInto: context)
    item.title = "article"
    item.point = .init(x: 4.5, y: 12)
    item.addToTags(tag)

    try context.save()
    context.reset()

    let request = NSFetchRequest<RuntimeSchemaItem>(entityName: "RuntimeSchemaItem")
    let fetched = try #require(context.fetch(request).first)
    #expect(fetched.title == "article")
    #expect(fetched.point?.x == 4.5)
    #expect(fetched.tags.count == 1)
  }
}
