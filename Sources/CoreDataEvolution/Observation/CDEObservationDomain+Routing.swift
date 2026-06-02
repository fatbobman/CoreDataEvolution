#if compiler(>=6.2)
  @preconcurrency import CoreData
  import Foundation

  @MainActor
  @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
  extension CDEObservationDomain {
    @discardableResult
    internal func routeMerge(
      affectedObjectIDs: [NSManagedObjectID],
      source: String = "merge"
    ) -> CDEObservationHubRoutePlan {
      var sameCycleSuppressedObjectIDs: Set<NSManagedObjectID> = []
      var plan = route(source: source, affectedObjectIDs: affectedObjectIDs) { objectID in
        guard let pending = pendingBuffer.consume(objectID: objectID) else {
          // A merge echo of a local `viewContext` save that was already precise-dispatched at
          // `didSave` (CloudKit/PHT re-merge). Swallow it instead of widening to all-key — the UI
          // updated at `didSave`. Consulted only on echo sources, never the local-save route itself;
          // the refreshed half of this same notification is suppressed via the returned set.
          if source != Self.viewContextSaveSource, fulfillPreciseRouteEchoMarker(objectID) {
            sameCycleSuppressedObjectIDs.insert(objectID)
            debugLog(
              "route source=\(source) objectID=\(debugObjectID(objectID)) skipped=precise-route-echo"
            )
            return nil
          }
          // Empty pending means one of two things, told apart ONLY by the same-cycle guard (see
          // `sameCyclePreciseMergeSuppressions`):
          //   • guard armed  → a DUPLICATE merge of an object already routed precisely this cycle.
          //     Must NOT widen to all-key, or it wakes unchanged siblings (the `content`→`date` bug).
          //   • guard unset  → a genuinely new / unobserved save (e.g. a plain `context.save()`).
          //     Must fall back to all-key.
          // Do not "simplify" this to always return `.allObservableKeyPaths`: that is exactly
          // regression (a) and re-breaks SwiftUI precision on duplicate merges.
          if consumeSameCyclePreciseMergeSuppression(objectID, clearsRemaining: true) {
            // Duplicate handled here; its refreshed half is routed later by the same caller, so report
            // the ID to keep that fallback from widening it to all-key.
            sameCycleSuppressedObjectIDs.insert(objectID)
            debugLog(
              "route source=\(source) objectID=\(debugObjectID(objectID)) skipped=same-cycle-precise"
            )
            return nil
          }
          return .allObservableKeyPaths
        }
        if case .fieldSet = pending {
          // When echo suppression is enabled, EVERY precise route arms the cross-cycle marker: both a
          // local `viewContext` save and a background/merge precise route echo back via CloudKit/PHT a
          // run-loop turn later (confirmed on device: a background save echoed ~93ms later). The marker
          // survives that sleep; the same-cycle guard — cleared on the first `beforeWaiting` — catches a
          // cross-cycle echo only by luck (when the run loop happens not to idle in the gap). The guard
          // remains for the disabled / plain-container path, which has no cross-cycle echo to outlive.
          if isPreciseRouteEchoSuppressionEnabled {
            armPreciseRouteEchoMarker(objectID)
          } else {
            markSameCyclePreciseMerge(objectID)
          }
        }
        return pending
      }
      // Preserve skipped duplicate IDs for same-notification refresh suppression. Do not keep this as
      // domain state; the same-cycle table itself remains short-lived to avoid hiding later saves.
      plan.sameCycleSuppressedObjectIDs = sameCycleSuppressedObjectIDs
      return plan
    }

    @discardableResult
    internal func routeAllKeyFallback(
      affectedObjectIDs: [NSManagedObjectID]
    ) -> CDEObservationHubRoutePlan {
      routeAllKeyFallback(
        affectedObjectIDs: affectedObjectIDs,
        source: "allKeyFallback",
        skipsProducerBackedPrecise: false
      )
    }

    @discardableResult
    internal func routeAllKeyFallback(
      affectedObjectIDs: [NSManagedObjectID],
      source: String = "allKeyFallback",
      skipsProducerBackedPrecise: Bool = false
    ) -> CDEObservationHubRoutePlan {
      routeAllKeyFallback(
        affectedObjectIDs: affectedObjectIDs,
        source: source,
        suppressingObjectIDs: [],
        skipsProducerBackedPrecise: skipsProducerBackedPrecise
      )
    }

    @discardableResult
    internal func routeAllKeyFallback(
      affectedObjectIDs: [NSManagedObjectID],
      source: String = "allKeyFallback",
      suppressingObjectIDs: Set<NSManagedObjectID>,
      skipsProducerBackedPrecise: Bool
    ) -> CDEObservationHubRoutePlan {
      route(source: source, affectedObjectIDs: affectedObjectIDs) { objectID in
        guard suppressingObjectIDs.contains(objectID) == false else {
          debugLog(
            "route source=\(source) objectID=\(debugObjectID(objectID)) skipped=suppressed"
          )
          return nil
        }
        if skipsProducerBackedPrecise {
          guard pendingBuffer.hasProducerBackedPendingChange(for: objectID) == false else {
            debugLog(
              "route source=\(source) objectID=\(debugObjectID(objectID)) skipped=producer-backed-precise"
            )
            return nil
          }
        }
        pendingBuffer.clear(objectID: objectID)
        return .allObservableKeyPaths
      }
    }

    internal func removeObservedObjects(_ objectIDs: [NSManagedObjectID]) {
      for objectID in objectIDs {
        observedObjects.unregister(objectID)
        pendingBuffer.clear(objectID: objectID)
      }
    }

    internal func resetObservedObjectsAndPendingChanges() {
      observedObjects.removeAll()
      pendingBuffer.removeAll()
    }

    private func route(
      source: String,
      affectedObjectIDs: [NSManagedObjectID],
      decision: (NSManagedObjectID) -> CDEObservationInvalidationDecision?
    ) -> CDEObservationHubRoutePlan {
      var decisions: [NSManagedObjectID: CDEObservationInvalidationDecision] = [:]
      var lookupCount = 0

      for objectID in affectedObjectIDs {
        lookupCount += 1
        guard let objectDecision = decision(objectID) else {
          continue
        }
        guard let object = observedObjects.object(for: objectID) else {
          continue
        }

        decisions[objectID] = objectDecision
        debugLog(
          "route source=\(source) object=\(type(of: object)) objectID=\(debugObjectID(objectID)) decision=\(debugDecision(objectDecision))"
        )
        dispatchInvalidation(on: object, decision: objectDecision)
        invalidationHandler?(object, objectDecision)
      }

      return .init(decisionsByObjectID: decisions, lookupCount: lookupCount)
    }

    private func dispatchInvalidation(
      on object: NSManagedObject,
      decision: CDEObservationInvalidationDecision
    ) {
      guard let dispatcher = object as? any CDEObservationInvalidationDispatching else {
        return
      }

      // Degradation remains object-scoped: the generated dispatcher walks only this model instance's
      // observable key paths and never traverses relationships to related objects.
      switch decision {
      case .fieldSet(let fieldSet):
        dispatcher.__cdObservationInvalidate(fieldSet: fieldSet)
      case .allObservableKeyPaths:
        dispatcher.__cdObservationInvalidateAllObservableKeyPaths()
      }
    }
  }

#endif
