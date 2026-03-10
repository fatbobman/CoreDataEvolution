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
  var tags: Set<Tag> {
    get {
      // Expose a plain Swift Set<T> at the public API boundary.
      // This bridges and copies the underlying NSSet on every access.
      (value(forKey: "tags") as? NSSet)?
        .compactMap {
        $0 as? Tag
      }
        .reduce(into: Set<Tag>()) {
        $0.insert($1)
      }
        ?? []
    }
  }
  var orderedCategories: [Category] {
    get {
      // Expose a plain Swift [T] at the public API boundary.
      // This bridges and copies the underlying NSOrderedSet on every access.
      (value(forKey: "orderedCategories") as? NSOrderedSet)?
        .compactMap {
        $0 as? Category
      }
        ?? []
    }
  }
}