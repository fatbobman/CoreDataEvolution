@preconcurrency import CoreData
import Foundation

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
internal struct CDEObservationSaveToken: Hashable, Sendable {
  private let id = UUID()

  internal init() {}
}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
internal enum CDEObservationInvalidationDecision: Equatable, Sendable {
  case fieldSet(CDEObservationFieldSet)
  case allObservableKeyPaths

  internal func merged(with other: CDEObservationInvalidationDecision)
    -> CDEObservationInvalidationDecision
  {
    switch (self, other) {
    case (.allObservableKeyPaths, _), (_, .allObservableKeyPaths):
      return .allObservableKeyPaths
    case (.fieldSet(let lhs), .fieldSet(let rhs)):
      return .fieldSet(lhs.union(rhs))
    }
  }
}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
internal final class CDEObservationPendingBuffer: @unchecked Sendable {
  private struct PendingObjectChange {
    var decision: CDEObservationInvalidationDecision
    var tokens: Set<CDEObservationSaveToken>
  }

  private let lock = NSLock()
  private var pendingByObjectID: [NSManagedObjectID: PendingObjectChange] = [:]
  private var tokenIndex: [CDEObservationSaveToken: Set<NSManagedObjectID>] = [:]
  private var tokenContributions:
    [CDEObservationSaveToken: [NSManagedObjectID: CDEObservationInvalidationDecision]] = [:]
  private var producerBackedTokens: Set<CDEObservationSaveToken> = []

  internal var pendingObjectCount: Int {
    lock.withLock { pendingByObjectID.count }
  }

  internal var tokenCount: Int {
    lock.withLock { tokenIndex.count }
  }

  internal func register(
    token: CDEObservationSaveToken,
    objectID: NSManagedObjectID,
    fieldSet: CDEObservationFieldSet
  ) {
    guard fieldSet.isEmpty == false else {
      return
    }

    register(token: token, objectID: objectID, decision: .fieldSet(fieldSet))
  }

  internal func register(
    token: CDEObservationSaveToken,
    changesByObjectID: [NSManagedObjectID: CDEObservationFieldSet]
  ) {
    register(
      token: token,
      changesByObjectID: changesByObjectID,
      preservesDuringLifecycleFallback: false
    )
  }

  internal func register(
    token: CDEObservationSaveToken,
    changesByObjectID: [NSManagedObjectID: CDEObservationFieldSet],
    preservesDuringLifecycleFallback: Bool
  ) {
    for (objectID, fieldSet) in changesByObjectID {
      guard fieldSet.isEmpty == false else {
        continue
      }
      register(
        token: token,
        objectID: objectID,
        decision: .fieldSet(fieldSet),
        preservesDuringLifecycleFallback: preservesDuringLifecycleFallback
      )
    }
  }

  internal func pendingChange(
    for objectID: NSManagedObjectID
  ) -> CDEObservationInvalidationDecision? {
    lock.withLock { pendingByObjectID[objectID]?.decision }
  }

  internal func hasProducerBackedPendingChange(for objectID: NSManagedObjectID) -> Bool {
    lock.withLock {
      pendingByObjectID[objectID]?.tokens.contains { token in
        producerBackedTokens.contains(token)
      } == true
    }
  }

  internal func consume(
    objectID: NSManagedObjectID
  ) -> CDEObservationInvalidationDecision? {
    lock.withLock {
      guard let pending = pendingByObjectID.removeValue(forKey: objectID) else {
        return nil
      }

      for token in pending.tokens {
        tokenIndex[token]?.remove(objectID)
        tokenContributions[token]?.removeValue(forKey: objectID)
        if tokenIndex[token]?.isEmpty == true {
          tokenIndex.removeValue(forKey: token)
          tokenContributions.removeValue(forKey: token)
          producerBackedTokens.remove(token)
        }
      }

      return pending.decision
    }
  }

  internal func clear(objectID: NSManagedObjectID) {
    _ = consume(objectID: objectID)
  }

  internal func removeAll() {
    lock.withLock {
      pendingByObjectID.removeAll()
      tokenIndex.removeAll()
      tokenContributions.removeAll()
      producerBackedTokens.removeAll()
    }
  }

  internal func rollback(token: CDEObservationSaveToken) {
    lock.withLock {
      rollbackLocked(token: token)
    }
  }

  internal func compress(objectID: NSManagedObjectID) {
    lock.withLock {
      guard var pending = pendingByObjectID[objectID] else {
        return
      }

      pending.decision = .allObservableKeyPaths
      pendingByObjectID[objectID] = pending

      for token in pending.tokens {
        tokenContributions[token]?[objectID] = .allObservableKeyPaths
      }
    }
  }

  private func register(
    token: CDEObservationSaveToken,
    objectID: NSManagedObjectID,
    decision: CDEObservationInvalidationDecision
  ) {
    register(
      token: token,
      objectID: objectID,
      decision: decision,
      preservesDuringLifecycleFallback: false
    )
  }

  private func register(
    token: CDEObservationSaveToken,
    objectID: NSManagedObjectID,
    decision: CDEObservationInvalidationDecision,
    preservesDuringLifecycleFallback: Bool
  ) {
    lock.withLock {
      tokenIndex[token, default: []].insert(objectID)
      tokenContributions[token, default: [:]][objectID] = decision
      if preservesDuringLifecycleFallback {
        producerBackedTokens.insert(token)
      }

      if var pending = pendingByObjectID[objectID] {
        pending.decision = pending.decision.merged(with: decision)
        pending.tokens.insert(token)
        pendingByObjectID[objectID] = pending
      } else {
        pendingByObjectID[objectID] = .init(decision: decision, tokens: [token])
      }
    }
  }

  private func rollbackLocked(token: CDEObservationSaveToken) {
    guard let objectIDs = tokenIndex.removeValue(forKey: token) else {
      return
    }
    tokenContributions.removeValue(forKey: token)
    producerBackedTokens.remove(token)

    for objectID in objectIDs {
      guard var pending = pendingByObjectID[objectID] else {
        continue
      }
      pending.tokens.remove(token)
      if let rebuilt = rebuildChangeLocked(for: objectID, tokens: pending.tokens) {
        pending.decision = rebuilt
        pendingByObjectID[objectID] = pending
      } else {
        pendingByObjectID.removeValue(forKey: objectID)
      }
    }
  }

  private func rebuildChangeLocked(
    for objectID: NSManagedObjectID,
    tokens: Set<CDEObservationSaveToken>
  ) -> CDEObservationInvalidationDecision? {
    tokens
      .compactMap { tokenContributions[$0]?[objectID] }
      .reduce(nil) { partial, decision in
        partial?.merged(with: decision) ?? decision
      }
  }
}

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

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
internal struct CDEObservationHubRoutePlan {
  internal var decisionsByObjectID: [NSManagedObjectID: CDEObservationInvalidationDecision]
  // A merge route can be intentionally suppressed by same-save duplicate protection. The caller
  // must still treat that object as handled when routing refreshed IDs from the same notification.
  internal var sameCycleSuppressedObjectIDs: Set<NSManagedObjectID>
  internal var lookupCount: Int

  internal init(
    decisionsByObjectID: [NSManagedObjectID: CDEObservationInvalidationDecision],
    sameCycleSuppressedObjectIDs: Set<NSManagedObjectID> = [],
    lookupCount: Int
  ) {
    self.decisionsByObjectID = decisionsByObjectID
    self.sameCycleSuppressedObjectIDs = sameCycleSuppressedObjectIDs
    self.lookupCount = lookupCount
  }
}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
internal typealias CDEObservationInvalidationHandler =
  @MainActor (NSManagedObject, CDEObservationInvalidationDecision) -> Void

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
private struct CDEObservationProducerStagedSave {
  var token: CDEObservationSaveToken
  var changesByObjectID: [NSManagedObjectID: CDEObservationFieldSet]
}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
/// Removable registration for an ordinary Core Data context that produces observation metadata.
public final class CDEObservationProducerRegistration: @unchecked Sendable {
  private weak var domain: CDEObservationDomain?
  private let context: NSManagedObjectContext
  private let lock = NSLock()
  private var observerTokens: [NSObjectProtocol] = []
  private var observing = true
  private var stagedSave: CDEObservationProducerStagedSave?
  private var committedTokens: Set<CDEObservationSaveToken> = []

  internal var isObserving: Bool {
    lock.withLock { observing }
  }

  internal var stagedSaveCount: Int {
    lock.withLock { stagedSave == nil ? 0 : 1 }
  }

  internal init(context: NSManagedObjectContext, domain: CDEObservationDomain) {
    self.context = context
    self.domain = domain
    installObservers()
  }

  deinit {
    invalidate()
  }

  /// Removes context observers and clears metadata produced by this registration.
  public func invalidate() {
    let state = lock.withLock {
      guard observing else {
        return (
          observerTokens: [NSObjectProtocol](),
          stagedSave: CDEObservationProducerStagedSave?.none,
          committedTokens: Set<CDEObservationSaveToken>()
        )
      }

      observing = false
      let tokens = observerTokens
      observerTokens.removeAll()
      let staged = stagedSave
      stagedSave = nil
      let committed = committedTokens
      committedTokens.removeAll()
      return (observerTokens: tokens, stagedSave: staged, committedTokens: committed)
    }

    for token in state.observerTokens {
      NotificationCenter.default.removeObserver(token)
    }
    if let stagedSave = state.stagedSave {
      domain?.rollbackPendingChangesFromProducer(token: stagedSave.token)
    }
    for token in state.committedTokens {
      domain?.rollbackPendingChangesFromProducer(token: token)
    }
  }

  private func installObservers() {
    observerTokens = [
      NotificationCenter.default.addObserver(
        forName: Notification.Name.NSManagedObjectContextWillSave,
        object: context,
        queue: nil
      ) { [weak self] notification in
        self?.stageSave(from: notification)
      },
      NotificationCenter.default.addObserver(
        forName: Notification.Name.NSManagedObjectContextDidSave,
        object: context,
        queue: nil
      ) { [weak self] notification in
        self?.commitSave(from: notification)
      },
      NotificationCenter.default.addObserver(
        forName: Notification.Name.NSManagedObjectContextObjectsDidChange,
        object: context,
        queue: nil
      ) { [weak self] notification in
        self?.handleObjectsDidChange(notification)
      },
    ]
  }

  private func stageSave(from notification: Notification) {
    guard notification.object as? NSManagedObjectContext === context else {
      return
    }

    let changes = collectChangedObservationFieldSets(from: context.updatedObjects)
    // Publish producer metadata in `willSave`, before automatic viewContext merge notifications can
    // race ahead and degrade an otherwise precise background save into all-key invalidation.
    var previousStagedSave: CDEObservationProducerStagedSave?
    var newStagedSave: CDEObservationProducerStagedSave?
    lock.withLock {
      guard observing else {
        return
      }

      previousStagedSave = stagedSave
      guard changes.isEmpty == false else {
        stagedSave = nil
        return
      }

      let staged = CDEObservationProducerStagedSave(
        token: CDEObservationSaveToken(),
        changesByObjectID: changes
      )
      stagedSave = staged
      newStagedSave = staged
    }

    if let previousStagedSave {
      // Replacing a staged save must also remove its early-published domain metadata; otherwise a
      // later lifecycle cleanup could consume stale field information for the same object.
      domain?.rollbackPendingChangesFromProducer(token: previousStagedSave.token)
    }
    if let newStagedSave {
      domain?.stagePendingChangesFromProducer(
        token: newStagedSave.token,
        changesByObjectID: newStagedSave.changesByObjectID
      )
    }
  }

  private func commitSave(from notification: Notification) {
    guard notification.object as? NSManagedObjectContext === context else {
      return
    }

    lock.withLock {
      guard observing, let staged = stagedSave else {
        stagedSave = nil
        return
      }

      stagedSave = nil
      committedTokens.insert(staged.token)
      // `willSave` publishes metadata early enough for automatic viewContext merges. `didSave`
      // only promotes the token; failed saves stay staged and are rolled back by rollback/reset.
    }
  }

  private func handleObjectsDidChange(_ notification: Notification) {
    guard notification.object as? NSManagedObjectContext === context else {
      return
    }

    if notification.userInfo?[NSInvalidatedAllObjectsKey] != nil {
      clearProducerState()
    } else {
      discardStagedSave()
    }
  }

  private func discardStagedSave() {
    let staged = lock.withLock {
      let staged = stagedSave
      stagedSave = nil
      return staged
    }

    if let staged {
      domain?.rollbackPendingChangesFromProducer(token: staged.token)
    }
  }

  private func clearProducerState() {
    let state = lock.withLock {
      let staged = stagedSave
      stagedSave = nil
      let committed = committedTokens
      committedTokens.removeAll()
      return (stagedSave: staged, committedTokens: committed)
    }

    if let stagedSave = state.stagedSave {
      domain?.rollbackPendingChangesFromProducer(token: stagedSave.token)
    }
    for token in state.committedTokens {
      domain?.rollbackPendingChangesFromProducer(token: token)
    }
  }
}

/// Policy for suppressing the cross-cycle echo of a `viewContext` local save.
///
/// A local `viewContext.save()` is precise-dispatched immediately at `didSave`. With history tracking
/// on (notably `NSPersistentCloudKitContainer`, even without a configured CloudKit container) the same
/// save is re-merged back into the `viewContext` a run-loop turn later; without suppression that echo
/// widens the precise change to all-key and wakes unchanged-sibling readers.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
public enum CDEPreciseRouteEchoSuppression: Sendable {
  /// Enabled only when the container is an `NSPersistentCloudKitContainer` (the strong signal that a
  /// local save echoes back). Plain containers stay off to avoid a stale marker eating a later merge.
  case auto
  /// Always enabled. Use when the app is known to re-merge local saves (PHT / CloudKit).
  case on
  /// Always disabled. Local saves consume their pending at `didSave`, as a plain container would.
  case off
}

@MainActor
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
/// Container-bound MainActor observation runtime for one Core Data `viewContext`.
public final class CDEObservationDomain {
  private let container: NSPersistentContainer
  private let viewContext: NSManagedObjectContext
  private let observedObjects = CDEObservationObjectIDTable()
  private let pendingBuffer = CDEObservationPendingBuffer()
  private let invalidationHandler: CDEObservationInvalidationHandler?
  private var observerTokens: [NSObjectProtocol] = []
  private var producerRegistrations: [CDEObservationProducerRegistration] = []
  private var pendingTemporaryObjectIDs: [(oldID: NSManagedObjectID, object: NSManagedObject)] = []
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
  private var sameCyclePreciseMergeSuppressions: [NSManagedObjectID: Int] = [:]

  // Precise-route echo suppression. A precise route (a `viewContext` local save, or a background/merge
  // route that consumes producer metadata) is precise-dispatched immediately; its history/CloudKit
  // re-merge echo arrives a run-loop turn later (cross `beforeWaiting`, so the same-cycle guard above
  // cannot reach it). This marker is armed at every precise route (when enabled) and makes the later
  // echo *skip* (the dispatch already happened) instead of widening to all-key.
  //
  // Deliberately NOT producer pending: producer pending means "re-route a field set when the merge
  // lands"; this marker means "the dispatch already happened, just swallow the echo" — so it carries
  // only the objectID, never a field set, and never re-dispatches. `honored` flips true on the first
  // echo hit; the `beforeWaiting` cleanup then drops honored (and TTL-expired) markers, while an
  // un-honored marker survives across drains waiting for its echo. Consulted on merge/refresh echo
  // routes; when disabled the same-cycle guard is used instead. See the cleanup observer.
  private struct PreciseRouteEchoMarker {
    var honored: Bool
    let armedAt: CFAbsoluteTime
  }
  private let isPreciseRouteEchoSuppressionEnabled: Bool
  private var preciseRouteEchoMarkers: [NSManagedObjectID: PreciseRouteEchoMarker] = [:]
  // Leak guard only (not a correctness primary): an un-honored marker is dropped after this long in
  // case an opted-in container produced a save that never echoed. Well above the observed ~23ms echo.
  private let preciseRouteEchoMarkerTTL: CFAbsoluteTime = 2

  // One repeating `kCFRunLoopBeforeWaiting` observer serves both the same-cycle guard and the
  // precise-route echo markers; it self-removes once both are empty (see `runEchoGuardCleanup`).
  private var echoGuardCleanupObserver: CFRunLoopObserver?
  /// The `routeMerge` source string for a `viewContext` local save (vs. a background/merge route).
  private static let viewContextSaveSource = "viewContextDidSave"
  private var isActive = true
  /// Opt-in console tracing for diagnosing real SwiftUI/Core Data notification ordering.
  ///
  /// Unit tests cover the runtime invariants, but SwiftUI `@FetchRequest` and `viewContext.save()`
  /// can still produce app-only notification sequences. Keep this off by default and enable it only
  /// while investigating those integration routes.
  public var isDebugLoggingEnabled =
    ProcessInfo.processInfo.environment["CDE_OBSERVATION_DEBUG"] == "1"

  // Debug-only timing anchors: when did the viewContext last save, and when was the previous logged
  // notification. Used to quantify how far (in wall-clock and run-loop turns) a CloudKit / history
  // echo lands after the originating `viewContextDidSave`.
  private var debugLastDidSaveTime: CFAbsoluteTime?
  private var debugLastEventTime: CFAbsoluteTime?

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

  deinit {
    MainActor.assumeIsolated {
      invalidate()
    }
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

  private func installViewContextObservers() {
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

  private func markSameCyclePreciseMerge(_ objectID: NSManagedObjectID) {
    // Arm the guard the instant a precise field set is routed for X, so a same-cycle duplicate
    // merge / refresh echo for X is swallowed rather than widened to all-key. Budget 2 covers the
    // up-to-two echoes Core Data can post per cycle (e.g. a refreshed half plus a duplicate refresh);
    // the run-loop-drain cleanup clears any unused remainder before the next save.
    sameCyclePreciseMergeSuppressions[objectID] = 2
    debugLog("sameCycle mark objectID=\(debugObjectID(objectID)) remaining=2")
    ensureEchoGuardCleanupObserver()
  }

  private func armPreciseRouteEchoMarker(_ objectID: NSManagedObjectID) {
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
  private func fulfillPreciseRouteEchoMarker(_ objectID: NSManagedObjectID) -> Bool {
    guard preciseRouteEchoMarkers[objectID] != nil else {
      return false
    }
    preciseRouteEchoMarkers[objectID]?.honored = true
    return true
  }

  private func clearAllPreciseRouteEchoMarkers() {
    guard preciseRouteEchoMarkers.isEmpty == false else {
      return
    }
    debugLog("preciseRouteEcho clearAll count=\(preciseRouteEchoMarkers.count)")
    preciseRouteEchoMarkers.removeAll()
  }

  // Returns true iff X is currently guarded (caller must then swallow X instead of widening it).
  // The merge path passes `clearsRemaining: true` because it fully handles the duplicate in one shot;
  // the refresh path decrements by one so a second same-cycle echo is still covered.
  private func consumeSameCyclePreciseMergeSuppression(
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

  private func cancelEchoGuardCleanupObserver() {
    guard let observer = echoGuardCleanupObserver else {
      return
    }
    CFRunLoopObserverInvalidate(observer)
    echoGuardCleanupObserver = nil
  }

  private func objectIDs(
    fromObjectSetsIn notification: Notification,
    keys: [String]
  ) -> [NSManagedObjectID] {
    uniqueObjectIDs(
      keys.flatMap { key in
        (notification.userInfo?[key] as? Set<NSManagedObject>)?.map(\.objectID) ?? []
      }
    )
  }

  private func objectIDs(
    fromObjectIDSetsIn notification: Notification,
    keys: [String]
  ) -> [NSManagedObjectID] {
    uniqueObjectIDs(
      keys.flatMap { key in
        Array(notification.userInfo?[key] as? Set<NSManagedObjectID> ?? [])
      }
    )
  }

  private func objectIDs(from objects: Set<NSManagedObject>) -> [NSManagedObjectID] {
    uniqueObjectIDs(objects.map(\.objectID))
  }

  private func uniqueObjectIDs(_ objectIDs: [NSManagedObjectID]) -> [NSManagedObjectID] {
    var seen: Set<NSManagedObjectID> = []
    return objectIDs.filter { objectID in
      seen.insert(objectID).inserted
    }
  }

  private func debugLog(_ message: @autoclosure () -> String) {
    guard isDebugLoggingEnabled else {
      return
    }

    print("[CDEObservationDebug] \(message())")
  }

  private func debugDecision(_ decision: CDEObservationInvalidationDecision) -> String {
    switch decision {
    case .fieldSet(let fieldSet):
      return "fieldSet raw=\(fieldSet.rawValues)"
    case .allObservableKeyPaths:
      return "allObservableKeyPaths"
    }
  }

  private func debugChangedObjects(_ objects: Set<NSManagedObject>) -> String {
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

  private func debugObjectIDs(_ objectIDs: [NSManagedObjectID]) -> String {
    "[\(objectIDs.map(debugObjectID).joined(separator: ", "))]"
  }

  private func debugObjectID(_ objectID: NSManagedObjectID) -> String {
    objectID.uriRepresentation().absoluteString
  }

  // Sorted userInfo keys of a notification. The CloudKit / persistent-history re-merge echo carries
  // different keys than a plain local save (e.g. `NSObjectsChangedByMergeChangesKey`, history/query
  // generation tokens), which is how we tell a self-save echo apart from a foreign change.
  private func debugUserInfoKeys(_ notification: Notification) -> String {
    let keys = (notification.userInfo?.keys.map { "\($0)" } ?? []).sorted()
    return "userInfoKeys=\(keys)"
  }

  // Wall-clock deltas since the previous logged notification and since the last `viewContextDidSave`.
  // A large `dtDidSave` on the merge echo confirms it crosses a run-loop sleep (so the same-cycle
  // guard, cleared on `beforeWaiting`, cannot reach it).
  private func debugTiming() -> String {
    let now = CFAbsoluteTimeGetCurrent()
    let dtPrev = debugLastEventTime.map { String(format: "%.1f", (now - $0) * 1000) } ?? "n/a"
    let dtSave = debugLastDidSaveTime.map { String(format: "%.1f", (now - $0) * 1000) } ?? "n/a"
    debugLastEventTime = now
    return "dtPrev=\(dtPrev)ms dtDidSave=\(dtSave)ms"
  }
}

@MainActor
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
internal enum CDEObservationDomainRegistry {
  private final class WeakDomain {
    weak var domain: CDEObservationDomain?

    init(_ domain: CDEObservationDomain) {
      self.domain = domain
    }
  }

  private static var domainsByContextID: [ObjectIdentifier: WeakDomain] = [:]

  internal static func activate(
    _ domain: CDEObservationDomain,
    for viewContext: NSManagedObjectContext
  ) {
    domainsByContextID[ObjectIdentifier(viewContext)] = WeakDomain(domain)
  }

  internal static func domain(for context: NSManagedObjectContext) -> CDEObservationDomain? {
    let contextID = ObjectIdentifier(context)
    guard let entry = domainsByContextID[contextID] else {
      return nil
    }

    guard let domain = entry.domain else {
      domainsByContextID.removeValue(forKey: contextID)
      return nil
    }

    return domain
  }

  internal static func deactivate(
    _ domain: CDEObservationDomain,
    for viewContext: NSManagedObjectContext
  ) {
    let contextID = ObjectIdentifier(viewContext)
    guard domainsByContextID[contextID]?.domain === domain else {
      return
    }

    domainsByContextID.removeValue(forKey: contextID)
  }
}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
internal func _cdeRegisterObservedObjectIfNeeded(_ object: NSManagedObject) {
  // Observation subscriptions are only routed for the MainActor/viewContext consumer.
  // Background getters can still read generated accessors, but they are producer-side work and
  // must not force a MainActor.assumeIsolated hop from a private Core Data queue.
  guard Thread.isMainThread else {
    return
  }

  nonisolated(unsafe) let unsafeObject = object
  MainActor.assumeIsolated {
    guard let context = unsafeObject.managedObjectContext else {
      return
    }

    CDEObservationDomainRegistry.domain(for: context)?.registerObservedObject(unsafeObject)
  }
}
