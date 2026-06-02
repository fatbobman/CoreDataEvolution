#if compiler(>=6.2)
  @preconcurrency import CoreData

  @MainActor
  @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
  internal final class CDEObservationObjectIDTable {
    private struct Entry {
      weak var object: NSManagedObject?
    }

    private var entries: [NSManagedObjectID: Entry] = [:]

    internal func register(_ object: NSManagedObject) {
      entries[object.objectID] = .init(object: object)
    }

    internal func rekey(_ object: NSManagedObject, from oldID: NSManagedObjectID) {
      entries.removeValue(forKey: oldID)
      entries[object.objectID] = .init(object: object)
    }

    internal func object(for objectID: NSManagedObjectID) -> NSManagedObject? {
      guard let object = entries[objectID]?.object else {
        entries.removeValue(forKey: objectID)
        return nil
      }
      return object
    }

    internal func contains(_ objectID: NSManagedObjectID) -> Bool {
      object(for: objectID) != nil
    }

    internal func unregister(_ objectID: NSManagedObjectID) {
      entries.removeValue(forKey: objectID)
    }

    internal func removeAll() {
      entries.removeAll()
    }

    internal var liveObjectIDs: Set<NSManagedObjectID> {
      entries = entries.filter { $0.value.object != nil }
      return Set(entries.keys)
    }
  }

#endif
