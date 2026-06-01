@preconcurrency import CoreData
import Foundation

@MainActor
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
extension CDEObservationDomain {
  internal func markSameCyclePreciseMerge(_ objectID: NSManagedObjectID) {
    // Arm the guard the instant a precise field set is routed for X, so a same-cycle duplicate
    // merge / refresh echo for X is swallowed rather than widened to all-key. Budget 2 covers the
    // up-to-two echoes Core Data can post per cycle (e.g. a refreshed half plus a duplicate refresh);
    // the run-loop-drain cleanup clears any unused remainder before the next save.
    sameCyclePreciseMergeSuppressions[objectID] = 2
    debugLog("sameCycle mark objectID=\(debugObjectID(objectID)) remaining=2")
    ensureEchoGuardCleanupObserver()
  }

  internal func armPreciseRouteEchoMarker(_ objectID: NSManagedObjectID) {
    preciseRouteEchoMarkers[objectID] = PreciseRouteEchoMarker(
      honored: false,
      armedAt: CFAbsoluteTimeGetCurrent()
    )
    debugLog("preciseRouteEcho arm objectID=\(debugObjectID(objectID))")
    ensureEchoGuardCleanupObserver()
  }

  // Returns true iff `objectID` is a pending precise-route echo (caller must then skip it). Marks the
  // marker `honored` so the next `beforeWaiting` drops it; it does not remove the marker itself, so
  // every echo notification for the same object in this turn (objectsDidChange + didMerge) skips.
  internal func fulfillPreciseRouteEchoMarker(_ objectID: NSManagedObjectID) -> Bool {
    guard preciseRouteEchoMarkers[objectID] != nil else {
      return false
    }
    preciseRouteEchoMarkers[objectID]?.honored = true
    return true
  }

  internal func clearAllPreciseRouteEchoMarkers() {
    guard preciseRouteEchoMarkers.isEmpty == false else {
      return
    }
    debugLog("preciseRouteEcho clearAll count=\(preciseRouteEchoMarkers.count)")
    preciseRouteEchoMarkers.removeAll()
  }

  // Returns true iff X is currently guarded (caller must then swallow X instead of widening it).
  // The merge path passes `clearsRemaining: true` because it fully handles the duplicate in one shot;
  // the refresh path decrements by one so a second same-cycle echo is still covered.
  internal func consumeSameCyclePreciseMergeSuppression(
    _ objectID: NSManagedObjectID,
    clearsRemaining: Bool = false
  ) -> Bool {
    guard let remaining = sameCyclePreciseMergeSuppressions[objectID], remaining > 0 else {
      return false
    }

    if clearsRemaining || remaining == 1 {
      sameCyclePreciseMergeSuppressions.removeValue(forKey: objectID)
    } else {
      sameCyclePreciseMergeSuppressions[objectID] = remaining - 1
    }
    return true
  }

  // Cleanup boundary for BOTH the same-cycle guard and the precise-route echo markers. Do NOT swap this
  // for a plain `Task`, `Task.yield()`, `DispatchQueue.main.async`, or a synchronous clear — each
  // re-introduces one of the two regressions documented on `sameCyclePreciseMergeSuppressions`
  // (too-early clear ⇒ SwiftUI spurious wake; starvable/racy clear ⇒ stale guard eats the next save's
  // fallback).
  //
  // A `kCFRunLoopBeforeWaiting` observer fires only when the run loop has drained *all* queued work
  // (every notification of the current burst, across however many turns) and is about to sleep —
  // unlike a queued item it cannot be starved or reordered ahead of a still-pending merge, and unlike
  // a fixed number of hops it does not race a back-to-back save (the next save is a later wakeup).
  //
  // It is `repeats: true` because a precise-route echo marker must survive across multiple sleeps until
  // its cross-cycle echo lands; the same-cycle guard still clears on the first fire. The observer
  // self-removes once both tables are empty (see `runEchoGuardCleanup`).
  private func ensureEchoGuardCleanupObserver() {
    guard echoGuardCleanupObserver == nil else {
      return
    }

    let observer = CFRunLoopObserverCreateWithHandler(
      kCFAllocatorDefault,
      CFRunLoopActivity.beforeWaiting.rawValue,
      true,  // repeating: precise-route echo markers can wait several sleeps for their echo
      0
    ) { [weak self] _, _ in
      MainActor.assumeIsolated {
        self?.runEchoGuardCleanup()
      }
    }
    echoGuardCleanupObserver = observer
    CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)
  }

  private func runEchoGuardCleanup() {
    // Same-cycle guard is same-cycle by definition: clear it on this (the first) drain.
    let sameCycleCleared = sameCyclePreciseMergeSuppressions.count
    sameCyclePreciseMergeSuppressions.removeAll()

    // Precise-route echo markers: drop the ones already honored by their echo, and TTL-expired ones (leak
    // guard); keep un-honored, in-TTL markers across this drain — they are still awaiting their echo.
    let now = CFAbsoluteTimeGetCurrent()
    let localBefore = preciseRouteEchoMarkers.count
    preciseRouteEchoMarkers = preciseRouteEchoMarkers.filter { _, marker in
      let expired = (now - marker.armedAt) > preciseRouteEchoMarkerTTL
      return marker.honored == false && expired == false
    }
    let localCleared = localBefore - preciseRouteEchoMarkers.count

    if sameCycleCleared > 0 || localCleared > 0 {
      debugLog(
        "echoGuard cleanup sameCycle=\(sameCycleCleared) preciseRouteEcho=\(localCleared) remaining=\(preciseRouteEchoMarkers.count)"
      )
    }

    // Stop the repeating observer once there is nothing left to watch.
    if sameCyclePreciseMergeSuppressions.isEmpty, preciseRouteEchoMarkers.isEmpty {
      cancelEchoGuardCleanupObserver()
    }
  }

  internal func cancelEchoGuardCleanupObserver() {
    guard let observer = echoGuardCleanupObserver else {
      return
    }
    CFRunLoopObserverInvalidate(observer)
    echoGuardCleanupObserver = nil
  }
}
