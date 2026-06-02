#if compiler(>=6.2)
  @preconcurrency import CoreData
  import Foundation

  @MainActor
  @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
  extension CDEObservationDomain {
    internal func installViewContextObservers() {
      observerTokens = [
        NotificationCenter.default.addObserver(
          forName: Notification.Name.NSManagedObjectContextWillSave,
          object: viewContext,
          queue: nil
        ) { [weak self] notification in
          // The viewContext posts these synchronously on MainActor; staging through an async hop
          // would let save/merge consume metadata before the will-save snapshot is visible.
          nonisolated(unsafe) let unsafeNotification = notification
          MainActor.assumeIsolated {
            self?.handleViewContextWillSave(unsafeNotification)
          }
        },
        NotificationCenter.default.addObserver(
          forName: Notification.Name.NSManagedObjectContextDidSave,
          object: viewContext,
          queue: nil
        ) { [weak self] notification in
          // See the will-save observer above for the synchronous MainActor handoff invariant.
          nonisolated(unsafe) let unsafeNotification = notification
          MainActor.assumeIsolated {
            self?.handleViewContextDidSave(unsafeNotification)
          }
        },
        NotificationCenter.default.addObserver(
          forName: Notification.Name.NSManagedObjectContextObjectsDidChange,
          object: viewContext,
          queue: nil
        ) { [weak self] notification in
          // See the will-save observer above for the synchronous MainActor handoff invariant.
          nonisolated(unsafe) let unsafeNotification = notification
          MainActor.assumeIsolated {
            self?.handleViewContextObjectsDidChange(unsafeNotification)
          }
        },
        NotificationCenter.default.addObserver(
          forName: NSManagedObjectContext.didMergeChangesObjectIDsNotification,
          object: viewContext,
          queue: nil
        ) { [weak self] notification in
          // See the will-save observer above for the synchronous MainActor handoff invariant.
          nonisolated(unsafe) let unsafeNotification = notification
          MainActor.assumeIsolated {
            self?.handleViewContextDidMergeObjectIDs(unsafeNotification)
          }
        },
      ]
    }

    private func handleViewContextWillSave(_ notification: Notification) {
      guard isActive, notification.object as? NSManagedObjectContext === viewContext else {
        return
      }

      // Hard boundary: a new local save opens a fresh cycle, so drop any prior precise-route echo markers
      // before re-arming. This bounds an un-honored marker (e.g. a save whose echo never came) so it
      // cannot survive into — and wrongly swallow — a later save's merge.
      clearAllPreciseRouteEchoMarkers()
      let token = CDEObservationSaveToken()
      let changes = collectChangedObservationFieldSets(from: viewContext.updatedObjects)
      debugLog(
        "notification source=viewContextWillSave changes=\(debugChangedObjects(viewContext.updatedObjects)) \(debugTiming()) \(debugUserInfoKeys(notification))"
      )
      pendingBuffer.register(token: token, changesByObjectID: changes)
      pendingTemporaryObjectIDs = viewContext.insertedObjects.compactMap { object in
        guard object.objectID.isTemporaryID, observedObjects.contains(object.objectID) else {
          return nil
        }
        return (oldID: object.objectID, object: object)
      }
    }

    private func handleViewContextDidSave(_ notification: Notification) {
      guard isActive, notification.object as? NSManagedObjectContext === viewContext else {
        return
      }

      rekeyTemporaryObservedObjects()
      let deletedObjectIDs = objectIDs(fromObjectSetsIn: notification, keys: [NSDeletedObjectsKey])
      let savedObjectIDs = objectIDs(
        fromObjectSetsIn: notification,
        keys: [NSInsertedObjectsKey, NSUpdatedObjectsKey]
      )
      removeObservedObjects(deletedObjectIDs)
      debugLog(
        "notification source=viewContextDidSave saved=\(debugObjectIDs(savedObjectIDs)) deleted=\(debugObjectIDs(deletedObjectIDs)) \(debugTiming()) \(debugUserInfoKeys(notification))"
      )
      if isDebugLoggingEnabled {
        debugLastDidSaveTime = CFAbsoluteTimeGetCurrent()
      }
      routeMerge(affectedObjectIDs: savedObjectIDs, source: "viewContextDidSave")
    }

    private func handleViewContextDidMergeObjectIDs(_ notification: Notification) {
      guard isActive, notification.object as? NSManagedObjectContext === viewContext else {
        return
      }

      let deletedObjectIDs = objectIDs(
        fromObjectIDSetsIn: notification,
        keys: [NSDeletedObjectIDsKey]
      )
      let mergedObjectIDs = objectIDs(
        fromObjectIDSetsIn: notification,
        keys: [
          NSInsertedObjectIDsKey,
          NSUpdatedObjectIDsKey,
        ]
      )
      let refreshedObjectIDs = objectIDs(
        fromObjectIDSetsIn: notification,
        keys: [NSRefreshedObjectIDsKey, NSInvalidatedObjectIDsKey]
      )
      // Batch deletes arrive as object IDs rather than deleted instances, so route one final
      // object-scoped fallback before unregistering the live viewContext object.
      debugLog(
        "notification source=didMergeObjectIDs merged=\(debugObjectIDs(mergedObjectIDs)) "
          + "refreshed=\(debugObjectIDs(refreshedObjectIDs)) deleted=\(debugObjectIDs(deletedObjectIDs)) "
          + "\(debugTiming()) \(debugUserInfoKeys(notification))"
      )
      routeAllKeyFallback(
        affectedObjectIDs: deletedObjectIDs,
        source: "didMergeObjectIDs-delete"
      )
      removeObservedObjects(deletedObjectIDs)
      let mergePlan = routeMerge(
        affectedObjectIDs: mergedObjectIDs,
        source: "didMergeObjectIDs"
      )
      let preciseRoutedObjectIDs = Set(
        mergePlan.decisionsByObjectID.compactMap { objectID, decision in
          if case .fieldSet = decision {
            return objectID
          }
          return nil
        }
      ).union(mergePlan.sameCycleSuppressedObjectIDs)
      // A Core Data merge notification can list the same object as both updated and refreshed, and
      // duplicate merge notifications can leave only the refreshed half after routeMerge is skipped.
      // Both cases are same-notification noise; neither should widen a precise save to all-key.
      routeAllKeyFallback(
        affectedObjectIDs: refreshedObjectIDs,
        source: "didMergeObjectIDs-refresh",
        suppressingObjectIDs: preciseRoutedObjectIDs,
        skipsProducerBackedPrecise: true
      )
    }

    private func handleViewContextObjectsDidChange(_ notification: Notification) {
      guard isActive, notification.object as? NSManagedObjectContext === viewContext else {
        return
      }

      if notification.userInfo?[NSInvalidatedAllObjectsKey] != nil {
        resetObservedObjectsAndPendingChanges()
        return
      }

      let deletedObjectIDs = objectIDs(fromObjectSetsIn: notification, keys: [NSDeletedObjectsKey])
      let refreshedObjectIDs = objectIDs(
        fromObjectSetsIn: notification,
        keys: [NSRefreshedObjectsKey, NSInvalidatedObjectsKey]
      )
      // Core Data exposes this merge marker only as a userInfo key string; it is the reliable
      // difference between remote merge deletes and caller-owned local deletes.
      let isMergeDrivenObjectChange =
        notification.userInfo?["NSObjectsChangedByMergeChangesKey"] != nil
      let locallyDeletedObjectIDs = Set(viewContext.deletedObjects.map(\.objectID))
      let remotelyDeletedObjectIDs =
        isMergeDrivenObjectChange
        ? deletedObjectIDs
        : deletedObjectIDs.filter { objectID in
          locallyDeletedObjectIDs.contains(objectID) == false
        }
      // Remote/batch deletes can reach ObjectsDidChange before didMerge object IDs. Local deletes
      // remain cleanup-only per the lifecycle table because `deletedObjects` still owns them.
      debugLog(
        "notification source=objectsDidChange mergeDriven=\(isMergeDrivenObjectChange) "
          + "refreshed=\(debugObjectIDs(refreshedObjectIDs)) deleted=\(debugObjectIDs(deletedObjectIDs)) "
          + "\(debugTiming()) \(debugUserInfoKeys(notification))"
      )
      routeAllKeyFallback(
        affectedObjectIDs: remotelyDeletedObjectIDs,
        source: "objectsDidChange-delete"
      )
      removeObservedObjects(deletedObjectIDs)
      let fallbackObjectIDs = refreshedObjectIDs.filter { objectID in
        // Automatic background merges can refresh the viewContext object before the
        // didMergeChangesObjectIDs notification that consumes precise pending metadata.
        if pendingBuffer.hasProducerBackedPendingChange(for: objectID) {
          debugLog(
            "route source=objectsDidChange-refresh objectID=\(debugObjectID(objectID)) skipped=producer-backed-precise"
          )
          return false
        }
        // The refresh half of a precise-route echo (CloudKit/PHT re-merge of a save already dispatched at
        // `didSave`). Swallow it; the marker outlives the run-loop sleep between save and echo.
        if fulfillPreciseRouteEchoMarker(objectID) {
          debugLog(
            "route source=objectsDidChange-refresh objectID=\(debugObjectID(objectID)) skipped=precise-route-echo"
          )
          return false
        }
        // If the precise merge already fired, Core Data may still post a duplicate refresh before the
        // run-loop-drain cleanup runs (see `sameCyclePreciseMergeSuppressions`). Swallow only that
        // same-cycle echo; the guard is gone by the next save, so later saves stay fallback-capable.
        if consumeSameCyclePreciseMergeSuppression(objectID) {
          debugLog(
            "route source=objectsDidChange-refresh objectID=\(debugObjectID(objectID)) skipped=same-cycle-precise"
          )
          return false
        }
        return true
      }
      routeAllKeyFallback(
        affectedObjectIDs: fallbackObjectIDs,
        source: "objectsDidChange-refresh",
        skipsProducerBackedPrecise: true
      )
    }

    private func rekeyTemporaryObservedObjects() {
      for entry in pendingTemporaryObjectIDs {
        observedObjects.rekey(entry.object, from: entry.oldID)
      }
      pendingTemporaryObjectIDs.removeAll()
    }
  }

#endif
