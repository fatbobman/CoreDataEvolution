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
    for (objectID, fieldSet) in changesByObjectID {
      register(token: token, objectID: objectID, fieldSet: fieldSet)
    }
  }

  internal func pendingChange(
    for objectID: NSManagedObjectID
  ) -> CDEObservationInvalidationDecision? {
    lock.withLock { pendingByObjectID[objectID]?.decision }
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
    lock.withLock {
      tokenIndex[token, default: []].insert(objectID)
      tokenContributions[token, default: [:]][objectID] = decision

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
  internal var lookupCount: Int

  internal init(
    decisionsByObjectID: [NSManagedObjectID: CDEObservationInvalidationDecision],
    lookupCount: Int
  ) {
    self.decisionsByObjectID = decisionsByObjectID
    self.lookupCount = lookupCount
  }
}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
internal typealias CDEObservationInvalidationHandler =
  @MainActor (NSManagedObject, CDEObservationInvalidationDecision) -> Void

@MainActor
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
/// Container-bound MainActor observation runtime for one Core Data `viewContext`.
public final class CDEObservationDomain {
  private let viewContext: NSManagedObjectContext
  private let observedObjects = CDEObservationObjectIDTable()
  private let pendingBuffer = CDEObservationPendingBuffer()
  private let invalidationHandler: CDEObservationInvalidationHandler?
  private var observerTokens: [NSObjectProtocol] = []
  private var pendingTemporaryObjectIDs: [(oldID: NSManagedObjectID, object: NSManagedObject)] = []
  private var isActive = true

  /// Creates the retained observation runtime for one container's `viewContext`.
  public convenience init(container: NSPersistentContainer) {
    self.init(container: container, invalidationHandler: nil)
  }

  internal init(
    container: NSPersistentContainer,
    invalidationHandler: CDEObservationInvalidationHandler?
  ) {
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
    pendingBuffer.removeAll()
    observedObjects.removeAll()
    pendingTemporaryObjectIDs.removeAll()
    CDEObservationDomainRegistry.deactivate(self, for: viewContext)
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

  internal func pendingChange(
    for objectID: NSManagedObjectID
  ) -> CDEObservationInvalidationDecision? {
    pendingBuffer.pendingChange(for: objectID)
  }

  @discardableResult
  internal func routeMerge(affectedObjectIDs: [NSManagedObjectID]) -> CDEObservationHubRoutePlan {
    route(affectedObjectIDs: affectedObjectIDs) { objectID in
      pendingBuffer.consume(objectID: objectID) ?? .allObservableKeyPaths
    }
  }

  @discardableResult
  internal func routeAllKeyFallback(
    affectedObjectIDs: [NSManagedObjectID]
  ) -> CDEObservationHubRoutePlan {
    route(affectedObjectIDs: affectedObjectIDs) { objectID in
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
    let changes = collectChangedFieldSets(from: viewContext.updatedObjects)
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
    removeObservedObjects(objectIDs(fromObjectSetsIn: notification, keys: [NSDeletedObjectsKey]))
    routeMerge(
      affectedObjectIDs: objectIDs(
        fromObjectSetsIn: notification,
        keys: [NSInsertedObjectsKey, NSUpdatedObjectsKey]
      )
    )
  }

  private func handleViewContextDidMergeObjectIDs(_ notification: Notification) {
    guard isActive, notification.object as? NSManagedObjectContext === viewContext else {
      return
    }

    removeObservedObjects(
      objectIDs(
        fromObjectIDSetsIn: notification,
        keys: [NSDeletedObjectIDsKey]
      )
    )
    routeMerge(
      affectedObjectIDs: objectIDs(
        fromObjectIDSetsIn: notification,
        keys: [
          NSInsertedObjectIDsKey,
          NSUpdatedObjectIDsKey,
          NSRefreshedObjectIDsKey,
          NSInvalidatedObjectIDsKey,
        ]
      )
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

    removeObservedObjects(objectIDs(fromObjectSetsIn: notification, keys: [NSDeletedObjectsKey]))
    routeAllKeyFallback(
      affectedObjectIDs: objectIDs(
        fromObjectSetsIn: notification,
        keys: [NSRefreshedObjectsKey, NSInvalidatedObjectsKey]
      )
    )
  }

  private func collectChangedFieldSets(
    from objects: Set<NSManagedObject>
  ) -> [NSManagedObjectID: CDEObservationFieldSet] {
    objects.reduce(into: [:]) { result, object in
      guard object.objectID.isTemporaryID == false else {
        return
      }
      guard let modelType = type(of: object) as? any CDEObservationFieldMapProviding.Type else {
        return
      }

      let fieldSet = modelType.__cdObservationFieldSet(
        forCoreDataKeys: object.changedValues().keys
      )
      guard fieldSet.isEmpty == false else {
        return
      }

      result[object.objectID] = fieldSet
    }
  }

  private func rekeyTemporaryObservedObjects() {
    for entry in pendingTemporaryObjectIDs {
      observedObjects.rekey(entry.object, from: entry.oldID)
    }
    pendingTemporaryObjectIDs.removeAll()
  }

  private func route(
    affectedObjectIDs: [NSManagedObjectID],
    decision: (NSManagedObjectID) -> CDEObservationInvalidationDecision
  ) -> CDEObservationHubRoutePlan {
    var decisions: [NSManagedObjectID: CDEObservationInvalidationDecision] = [:]
    var lookupCount = 0

    for objectID in affectedObjectIDs {
      lookupCount += 1
      let objectDecision = decision(objectID)
      guard let object = observedObjects.object(for: objectID) else {
        continue
      }

      decisions[objectID] = objectDecision
      invalidationHandler?(object, objectDecision)
    }

    return .init(decisionsByObjectID: decisions, lookupCount: lookupCount)
  }

  private func objectIDs(
    fromObjectSetsIn notification: Notification,
    keys: [String]
  ) -> [NSManagedObjectID] {
    keys.flatMap { key in
      (notification.userInfo?[key] as? Set<NSManagedObject>)?.map(\.objectID) ?? []
    }
  }

  private func objectIDs(
    fromObjectIDSetsIn notification: Notification,
    keys: [String]
  ) -> [NSManagedObjectID] {
    keys.flatMap { key in
      Array(notification.userInfo?[key] as? Set<NSManagedObjectID> ?? [])
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
