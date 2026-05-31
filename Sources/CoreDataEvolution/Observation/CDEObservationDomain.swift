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
  private var sameCyclePreciseMergeSuppressions: [NSManagedObjectID: Int] = [:]
  private var sameCyclePrecisionCleanupTask: Task<Void, Never>?
  private var isActive = true

  /// Creates the retained observation runtime for one container's `viewContext`.
  public convenience init(container: NSPersistentContainer) {
    self.init(container: container, invalidationHandler: nil)
  }

  internal init(
    container: NSPersistentContainer,
    invalidationHandler: CDEObservationInvalidationHandler?
  ) {
    self.container = container
    viewContext = container.viewContext
    self.invalidationHandler = invalidationHandler
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
    sameCyclePrecisionCleanupTask?.cancel()
    sameCyclePrecisionCleanupTask = nil
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
  internal func routeMerge(affectedObjectIDs: [NSManagedObjectID]) -> CDEObservationHubRoutePlan {
    var sameCycleSuppressedObjectIDs: Set<NSManagedObjectID> = []
    var plan = route(affectedObjectIDs: affectedObjectIDs) { objectID in
      guard let pending = pendingBuffer.consume(objectID: objectID) else {
        if consumeSameCyclePreciseMergeSuppression(objectID, clearsRemaining: true) {
          // The duplicate merge is handled here, but its refreshed half is routed later by the same
          // caller. Return the object ID so that fallback path does not widen it to all-key.
          sameCycleSuppressedObjectIDs.insert(objectID)
          return nil
        }
        return .allObservableKeyPaths
      }
      if case .fieldSet = pending {
        markSameCyclePreciseMerge(objectID)
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
      skipsProducerBackedPrecise: false
    )
  }

  @discardableResult
  internal func routeAllKeyFallback(
    affectedObjectIDs: [NSManagedObjectID],
    skipsProducerBackedPrecise: Bool
  ) -> CDEObservationHubRoutePlan {
    routeAllKeyFallback(
      affectedObjectIDs: affectedObjectIDs,
      suppressingObjectIDs: [],
      skipsProducerBackedPrecise: skipsProducerBackedPrecise
    )
  }

  @discardableResult
  internal func routeAllKeyFallback(
    affectedObjectIDs: [NSManagedObjectID],
    suppressingObjectIDs: Set<NSManagedObjectID>,
    skipsProducerBackedPrecise: Bool
  ) -> CDEObservationHubRoutePlan {
    route(affectedObjectIDs: affectedObjectIDs) { objectID in
      guard suppressingObjectIDs.contains(objectID) == false else {
        return nil
      }
      if skipsProducerBackedPrecise {
        guard pendingBuffer.hasProducerBackedPendingChange(for: objectID) == false else {
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

    let token = CDEObservationSaveToken()
    let changes = collectChangedObservationFieldSets(from: viewContext.updatedObjects)
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
    routeMerge(affectedObjectIDs: savedObjectIDs)
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
    routeAllKeyFallback(affectedObjectIDs: deletedObjectIDs)
    removeObservedObjects(deletedObjectIDs)
    let mergePlan = routeMerge(affectedObjectIDs: mergedObjectIDs)
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
    routeAllKeyFallback(
      affectedObjectIDs: remotelyDeletedObjectIDs
    )
    removeObservedObjects(deletedObjectIDs)
    let fallbackObjectIDs = refreshedObjectIDs.filter { objectID in
      // Automatic background merges can refresh the viewContext object before the
      // didMergeChangesObjectIDs notification that consumes precise pending metadata.
      guard pendingBuffer.hasProducerBackedPendingChange(for: objectID) == false else {
        return false
      }
      // If the precise merge already fired, Core Data may still post a duplicate refresh before the
      // one-turn cleanup runs. Swallow only that duplicate; later saves remain fallback-capable.
      guard consumeSameCyclePreciseMergeSuppression(objectID) == false else {
        return false
      }
      return true
    }
    routeAllKeyFallback(
      affectedObjectIDs: fallbackObjectIDs,
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
    sameCyclePreciseMergeSuppressions[objectID] = 2
    scheduleSameCyclePrecisionCleanup()
  }

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

  private func scheduleSameCyclePrecisionCleanup() {
    guard sameCyclePrecisionCleanupTask == nil else {
      return
    }

    sameCyclePrecisionCleanupTask = Task { @MainActor [weak self] in
      await Task.yield()
      guard let self else {
        return
      }
      sameCyclePreciseMergeSuppressions.removeAll()
      sameCyclePrecisionCleanupTask = nil
    }
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
