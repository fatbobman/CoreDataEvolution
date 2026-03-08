import CoreData
import CoreDataEvolution

final class Tag: NSManagedObject, PersistentEntity {
}
final class Category: NSManagedObject, PersistentEntity {
}

final class Item: NSManagedObject {
  var tag: Tag? {
    get {
      value(forKey: "tag") as? Tag
    }
    set {
      setValue(newValue, forKey: "tag")
    }
  }
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
    set {
      setValue(NSSet(set: newValue), forKey: "tags")
    }
  }
  var orderedCategories: [Category] {
    get {
      (value(forKey: "orderedCategories") as? NSOrderedSet)?
        .compactMap {
        $0 as? Category
      }
        ?? []
    }
    set {
      setValue(NSOrderedSet(array: newValue), forKey: "orderedCategories")
    }
  }
}