import CoreData
import CoreDataEvolution

final class Tag: NSManagedObject, PersistentEntity {}
final class Category: NSManagedObject, PersistentEntity {}

final class Item: NSManagedObject {
  var tag: Tag? {
    get {
      value(forKey: "tag") as? Tag
    }
    set {
      setValue(newValue, forKey: "tag")
    }
  }

  private static let __cd_relationship_validate_tag_entity: Void = CoreDataEvolution._CDRelationshipMacroValidation.requirePersistentEntity(Tag.self)
  var tags: Set<Tag> {
    get {
      (value(forKey: "tags") as? NSSet)?
        .compactMap {
        $0 as? Tag
      }
        .reduce(into: Set<Tag>()) {
        $0.insert($1)
      }
        ?? []
    }
    @available(*, deprecated, message: "Bulk to-many setter may hide relationship mutation costs. Prefer add/remove helpers.")
    set {
      setValue(NSSet(set: newValue), forKey: "tags")
    }
  }

  private static let __cd_relationship_validate_tags_entity: Void = CoreDataEvolution._CDRelationshipMacroValidation.requirePersistentEntity(Tag.self)
  var orderedCategories: [Category] {
    get {
      (value(forKey: "orderedCategories") as? NSOrderedSet)?
        .compactMap {
        $0 as? Category
      }
        ?? []
    }
  }

  private static let __cd_relationship_validate_orderedCategories_entity: Void = CoreDataEvolution._CDRelationshipMacroValidation.requirePersistentEntity(Category.self)
}