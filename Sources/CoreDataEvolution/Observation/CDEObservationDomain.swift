#if compiler(>=6.2)
  @preconcurrency import CoreData
  import Foundation
  import OSLog

  @MainActor
  @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
  /// Container-bound MainActor observation runtime for one Core Data `viewContext`.
  public final class CDEObservationDomain {
    internal static let debugLogger = Logger(
      subsystem: "CoreDataEvolution",
      category: "Observation"
    )

    private let container: NSPersistentContainer
    internal let viewContext: NSManagedObjectContext
    internal let observedObjects = CDEObservationObjectIDTable()
    internal let pendingBuffer = CDEObservationPendingBuffer()
    internal let invalidationHandler: CDEObservationInvalidationHandler?
    internal var observerTokens: [NSObjectProtocol] = []
    private var producerRegistrations: [CDEObservationProducerRegistration] = []
    internal var pendingTemporaryObjectIDs: [(oldID: NSManagedObjectID, object: NSManagedObject)] =
      []
    // Same-cycle precise-merge guard. DO NOT remove or "simplify" either this guard or its run-loop
    // cleanup without reading this — both halves are load-bearing and have each regressed before.
    //
    // Symptom it prevents (SwiftUI, reproduced on device): a background save changes ONE field, say
    // `Memo.content`. Core Data merges it into the viewContext and `routeMerge` invalidates exactly
    // `content`. But Core Data can post a SECOND merge/refresh for the SAME object in the SAME save
    // cycle (a duplicate `didMergeChangesObjectIDs`, or the refreshed half of one notification). By
    // then the precise pending metadata is already consumed, so a naive route falls back to
    // `.allObservableKeyPaths` and wakes observers of UNCHANGED siblings — a view reading only
    // `Memo.date` refreshes spuriously.
    //
    // The guard records "objectID X was just precisely routed this cycle" (see
    // `markSameCyclePreciseMerge`); the three consumers swallow that echo instead of widening it:
    //   1. `routeMerge` — a duplicate merge whose pending is already consumed.
    //   2. `handleViewContextDidMergeObjectIDs` — the refreshed half of the same notification.
    //   3. `handleViewContextObjectsDidChange` — a duplicate refresh in a later turn of the cycle.
    //
    // Two regressions this has already caused — each re-broke one of the two requirements:
    //   (a) Dropping the guard / making `routeMerge` always all-key on empty pending → the duplicate
    //       merge widens precise→all-key again → the SwiftUI spurious-wake returns.
    //   (b) Clearing the guard on a fixed timer (`Task { await Task.yield() }`) → under MainActor load
    //       the clear is starved past the NEXT save, so a stale guard swallows that save's legitimate
    //       all-key fallback → flaky concurrency failure (a direct save right after an observed save).
    // The only correct lifetime is "the current run-loop event cycle": long enough to cover every
    // same-cycle echo, gone before the next user-initiated save. See `ensureEchoGuardCleanupObserver`.
    internal var sameCyclePreciseMergeSuppressions: [NSManagedObjectID: Int] = [:]

    // Precise-route echo suppression. A precise route (a `viewContext` local save, or a background/merge
    // route that consumes producer metadata) is precise-dispatched immediately; if the same change is
    // re-merged back into the `viewContext` a run-loop turn later (any merge source — commonly CloudKit /
    // PHT — handled generically, never source-inspected), that echo crosses `beforeWaiting`, so the
    // same-cycle guard above cannot reach it. This marker is armed at every precise route (when enabled)
    // and makes the later echo *skip* (the dispatch already happened) instead of widening to all-key.
    //
    // Deliberately NOT producer pending: producer pending means "re-route a field set when the merge
    // lands"; this marker means "the dispatch already happened, just swallow the echo" — so it carries
    // only the objectID, never a field set, and never re-dispatches. `honored` flips true on the first
    // echo hit; the `beforeWaiting` cleanup then drops honored (and TTL-expired) markers, while an
    // un-honored marker survives across drains waiting for its echo. Consulted on merge/refresh echo
    // routes; when disabled the same-cycle guard is used instead. See the cleanup observer.
    internal struct PreciseRouteEchoMarker {
      var honored: Bool
      let armedAt: CFAbsoluteTime
    }
    internal let isPreciseRouteEchoSuppressionEnabled: Bool
    internal var preciseRouteEchoMarkers: [NSManagedObjectID: PreciseRouteEchoMarker] = [:]
    // Leak guard only (not a correctness primary): an un-honored marker is dropped after this long in
    // case an opted-in container produced a save that never echoed. Well above the observed ~23ms echo.
    internal let preciseRouteEchoMarkerTTL: CFAbsoluteTime = 2

    // One repeating `kCFRunLoopBeforeWaiting` observer serves both the same-cycle guard and the
    // precise-route echo markers; it self-removes once both are empty (see `runEchoGuardCleanup`).
    internal var echoGuardCleanupObserver: CFRunLoopObserver?
    /// The `routeMerge` source string for a `viewContext` local save (vs. a background/merge route).
    internal static let viewContextSaveSource = "viewContextDidSave"
    internal var isActive = true
    /// Diagnostic tracing for real SwiftUI / Core Data notification ordering.
    ///
    /// Off by default and safe to ship: all output is gated by this flag and emitted through unified
    /// logging with subsystem `CoreDataEvolution` and category `Observation`. Enable it per process by
    /// setting the environment variable `CDE_OBSERVATION_DEBUG` to `1` / `true` / `yes` / `on`, or
    /// toggle this property directly on a domain instance while investigating an app-only notification
    /// sequence. The Boolean switch is public API; individual log message text is diagnostic and may
    /// change between releases.
    public var isDebugLoggingEnabled = CDEObservationDomain.debugLoggingEnabledByEnvironment

    /// The persistent container owned by this observation domain.
    public var modelContainer: NSPersistentContainer {
      container
    }

    private static let debugLoggingEnabledByEnvironment: Bool = {
      guard
        let value = ProcessInfo.processInfo.environment["CDE_OBSERVATION_DEBUG"]?
          .lowercased()
      else {
        return false
      }
      return ["1", "true", "yes", "on"].contains(value)
    }()

    // Debug-only timing anchors: when did the viewContext last save, and when was the previous logged
    // notification. Used to quantify how far (in wall-clock and run-loop turns) a CloudKit / history
    // echo lands after the originating `viewContextDidSave`.
    internal var debugLastDidSaveTime: CFAbsoluteTime?
    internal var debugLastEventTime: CFAbsoluteTime?

    /// Creates the retained observation runtime for one container's `viewContext`.
    ///
    /// - Parameter preciseRouteEchoSuppression: whether to swallow the cross-cycle re-merge echo of a
    ///   local `viewContext.save()`. Defaults to `.auto` (on for `NSPersistentCloudKitContainer`).
    public convenience init(
      container: NSPersistentContainer,
      preciseRouteEchoSuppression: CDEPreciseRouteEchoSuppression = .auto
    ) {
      self.init(
        container: container,
        preciseRouteEchoSuppression: preciseRouteEchoSuppression,
        invalidationHandler: nil
      )
    }

    internal init(
      container: NSPersistentContainer,
      preciseRouteEchoSuppression: CDEPreciseRouteEchoSuppression = .auto,
      invalidationHandler: CDEObservationInvalidationHandler?
    ) {
      self.container = container
      viewContext = container.viewContext
      self.invalidationHandler = invalidationHandler
      switch preciseRouteEchoSuppression {
      case .on:
        isPreciseRouteEchoSuppressionEnabled = true
      case .off:
        isPreciseRouteEchoSuppressionEnabled = false
      case .auto:
        // `NSPersistentCloudKitContainer` always enables history tracking and re-merges local saves,
        // so an echo is expected; plain containers stay off to avoid a stale marker on a no-echo save.
        isPreciseRouteEchoSuppressionEnabled = container is NSPersistentCloudKitContainer
      }
      CDEObservationDomainRegistry.activate(self, for: viewContext)
      installViewContextObservers()
    }

    isolated deinit {
      invalidate()
    }

    /// Tears down context observers and removes the getter lookup association.
    public func invalidate() {
      guard isActive else {
        return
      }

      isActive = false
      for token in observerTokens {
        NotificationCenter.default.removeObserver(token)
      }
      observerTokens.removeAll()
      for registration in producerRegistrations {
        registration.invalidate()
      }
      producerRegistrations.removeAll()
      pendingBuffer.removeAll()
      observedObjects.removeAll()
      pendingTemporaryObjectIDs.removeAll()
      sameCyclePreciseMergeSuppressions.removeAll()
      preciseRouteEchoMarkers.removeAll()
      cancelEchoGuardCleanupObserver()
      CDEObservationDomainRegistry.deactivate(self, for: viewContext)
    }

    /// Registers an ordinary context whose direct saves should produce precise observation metadata.
    @discardableResult
    public func registerChangeProducer(
      context: NSManagedObjectContext
    ) -> CDEObservationProducerRegistration {
      let registration = CDEObservationProducerRegistration(context: context, domain: self)
      producerRegistrations.append(registration)
      return registration
    }

    internal func removeProducerRegistration(_ registration: CDEObservationProducerRegistration) {
      producerRegistrations.removeAll { $0 === registration }
    }

    /// Creates and registers a background context for direct-save observation metadata.
    public func newObservedBackgroundContext() -> NSManagedObjectContext {
      let context = container.newBackgroundContext()
      registerChangeProducer(context: context)
      return context
    }

    /// Saves an arbitrary context with wrapper-owned rollback of staged observation metadata.
    public nonisolated func saveObservedChanges(in context: NSManagedObjectContext) async throws {
      try await withCheckedThrowingContinuation { continuation in
        context.perform {
          let token = CDEObservationSaveToken()
          let changes = collectChangedObservationFieldSets(from: context.updatedObjects)

          self.stagePendingChangesFromProducer(token: token, changesByObjectID: changes)
          do {
            try context.save()
            continuation.resume()
          } catch {
            self.rollbackPendingChangesFromProducer(token: token)
            context.rollback()
            continuation.resume(throwing: error)
          }
        }
      }
    }

    /// Rolls back the domain's `viewContext` and conservatively invalidates affected live objects.
    ///
    /// Newly inserted observed objects are unregistered instead of invalidated because rollback
    /// detaches them from the persistent graph.
    public func rollbackObservedChanges() {
      let insertedObjectIDs = objectIDs(from: viewContext.insertedObjects)
      let affectedObjectIDs = objectIDs(
        from: viewContext.updatedObjects.union(viewContext.deletedObjects)
      )

      viewContext.rollback()
      routeAllKeyFallback(affectedObjectIDs: affectedObjectIDs)
      removeObservedObjects(insertedObjectIDs)
    }

    internal var liveObservedObjectIDs: Set<NSManagedObjectID> {
      observedObjects.liveObjectIDs
    }

    internal var pendingObjectCount: Int {
      pendingBuffer.pendingObjectCount
    }

    internal var pendingTokenCount: Int {
      pendingBuffer.tokenCount
    }

    internal var producerRegistrationCount: Int {
      producerRegistrations.count
    }

    internal var sameCyclePrecisionGuardCount: Int {
      sameCyclePreciseMergeSuppressions.count
    }

    internal var preciseRouteEchoMarkerCount: Int {
      preciseRouteEchoMarkers.count
    }

    internal var isPreciseRouteEchoSuppressionActive: Bool {
      isPreciseRouteEchoSuppressionEnabled
    }

    internal func containsObservedObject(_ objectID: NSManagedObjectID) -> Bool {
      observedObjects.contains(objectID)
    }

    internal func registerObservedObject(_ object: NSManagedObject) {
      guard isActive, object.managedObjectContext === viewContext else {
        return
      }

      observedObjects.register(object)
    }

    internal func stagePendingChange(
      token: CDEObservationSaveToken,
      objectID: NSManagedObjectID,
      fieldSet: CDEObservationFieldSet
    ) {
      pendingBuffer.register(token: token, objectID: objectID, fieldSet: fieldSet)
    }

    internal func stagePendingChanges(
      token: CDEObservationSaveToken,
      changesByObjectID: [NSManagedObjectID: CDEObservationFieldSet]
    ) {
      pendingBuffer.register(token: token, changesByObjectID: changesByObjectID)
    }

    internal func rollbackPendingChanges(token: CDEObservationSaveToken) {
      pendingBuffer.rollback(token: token)
    }

    // Producer-side staging is intentionally nonisolated: CDE-managed background saves must not
    // suspend between their field snapshot and `save()`.
    internal nonisolated func stagePendingChangesFromProducer(
      token: CDEObservationSaveToken,
      changesByObjectID: [NSManagedObjectID: CDEObservationFieldSet]
    ) {
      pendingBuffer.register(
        token: token,
        changesByObjectID: changesByObjectID,
        preservesDuringLifecycleFallback: true
      )
    }

    internal nonisolated func rollbackPendingChangesFromProducer(token: CDEObservationSaveToken) {
      pendingBuffer.rollback(token: token)
    }

    internal func pendingChange(
      for objectID: NSManagedObjectID
    ) -> CDEObservationInvalidationDecision? {
      pendingBuffer.pendingChange(for: objectID)
    }
  }

#endif
