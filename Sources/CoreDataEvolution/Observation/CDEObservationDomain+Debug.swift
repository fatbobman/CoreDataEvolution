#if compiler(>=6.2)
  @preconcurrency import CoreData
  import Foundation
  import OSLog

  @MainActor
  @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
  extension CDEObservationDomain {
    internal func debugLog(_ message: @autoclosure () -> String) {
      guard isDebugLoggingEnabled else {
        return
      }

      let debugMessage = message()
      Self.debugLogger.debug("\(debugMessage, privacy: .public)")
    }

    internal func debugDecision(_ decision: CDEObservationInvalidationDecision) -> String {
      switch decision {
      case .fieldSet(let fieldSet):
        return "fieldSet raw=\(fieldSet.rawValues)"
      case .allObservableKeyPaths:
        return "allObservableKeyPaths"
      }
    }

    internal func debugChangedObjects(_ objects: Set<NSManagedObject>) -> String {
      guard objects.isEmpty == false else {
        return "[]"
      }

      let summaries =
        objects
        .sorted { lhs, rhs in
          debugObjectID(lhs.objectID) < debugObjectID(rhs.objectID)
        }
        .map { object -> String in
          let changedKeys = object.changedValues().keys.sorted()
          let fieldSet = (type(of: object) as? any CDEObservationFieldMapProviding.Type)?
            .__cdObservationFieldSet(forCoreDataKeys: changedKeys)
          let fieldSetDescription = fieldSet.map { " raw=\($0.rawValues)" } ?? ""
          return
            "\(type(of: object)) objectID=\(debugObjectID(object.objectID)) changedKeys=\(changedKeys)\(fieldSetDescription)"
        }
      return "[\(summaries.joined(separator: "; "))]"
    }

    internal func debugObjectIDs(_ objectIDs: [NSManagedObjectID]) -> String {
      "[\(objectIDs.map(debugObjectID).joined(separator: ", "))]"
    }

    internal func debugObjectID(_ objectID: NSManagedObjectID) -> String {
      objectID.uriRepresentation().absoluteString
    }

    // Sorted userInfo keys of a notification. The CloudKit / persistent-history re-merge echo carries
    // different keys than a plain local save (e.g. `NSObjectsChangedByMergeChangesKey`, history/query
    // generation tokens), which is how we tell a self-save echo apart from a foreign change.
    internal func debugUserInfoKeys(_ notification: Notification) -> String {
      let keys = (notification.userInfo?.keys.map { "\($0)" } ?? []).sorted()
      return "userInfoKeys=\(keys)"
    }

    // Wall-clock deltas since the previous logged notification and since the last `viewContextDidSave`.
    // A large `dtDidSave` on the merge echo confirms it crosses a run-loop sleep (so the same-cycle
    // guard, cleared on `beforeWaiting`, cannot reach it).
    internal func debugTiming() -> String {
      let now = CFAbsoluteTimeGetCurrent()
      let dtPrev = debugLastEventTime.map { String(format: "%.1f", (now - $0) * 1000) } ?? "n/a"
      let dtSave = debugLastDidSaveTime.map { String(format: "%.1f", (now - $0) * 1000) } ?? "n/a"
      debugLastEventTime = now
      return "dtPrev=\(dtPrev)ms dtDidSave=\(dtSave)ms"
    }
  }

#endif
