#if compiler(>=6.2)
  @preconcurrency import CoreData
  import Foundation

  @MainActor
  @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
  extension CDEObservationDomain {
    internal func objectIDs(
      fromObjectSetsIn notification: Notification,
      keys: [String]
    ) -> [NSManagedObjectID] {
      uniqueObjectIDs(
        keys.flatMap { key in
          (notification.userInfo?[key] as? Set<NSManagedObject>)?.map(\.objectID) ?? []
        }
      )
    }

    internal func objectIDs(
      fromObjectIDSetsIn notification: Notification,
      keys: [String]
    ) -> [NSManagedObjectID] {
      uniqueObjectIDs(
        keys.flatMap { key in
          Array(notification.userInfo?[key] as? Set<NSManagedObjectID> ?? [])
        }
      )
    }

    internal func objectIDs(from objects: Set<NSManagedObject>) -> [NSManagedObjectID] {
      uniqueObjectIDs(objects.map(\.objectID))
    }

    private func uniqueObjectIDs(_ objectIDs: [NSManagedObjectID]) -> [NSManagedObjectID] {
      var seen: Set<NSManagedObjectID> = []
      return objectIDs.filter { objectID in
        seen.insert(objectID).inserted
      }
    }
  }

#endif
