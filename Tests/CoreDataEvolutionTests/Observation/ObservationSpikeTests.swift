//
//  ------------------------------------------------
//  Original project: CoreDataEvolution
//  Created on 2026/5/30 by Fatbobman(东坡肘子)
//  X: @fatbobman
//  Mastodon: @fatbobman@mastodon.social
//  GitHub: @fatbobman
//  Blog: https://fatbobman.com
//  ------------------------------------------------
//  Copyright © 2024-present Fatbobman. All rights reserved.

@preconcurrency import CoreDataEvolution
import Foundation
import Testing

#if canImport(Observation)
  import Observation
#endif

#if canImport(Observation)
  @available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *)
  private final class ObservationProbeObject: Observable {
    private let observationRegistrar = ObservationRegistrar()
    private var nameStorage = ""
    private var timestampStorage: Date?

    var name: String {
      get {
        observationRegistrar.access(self, keyPath: \.name)
        return nameStorage
      }
      set {
        observationRegistrar.withMutation(of: self, keyPath: \.name) {
          nameStorage = newValue
        }
      }
    }

    var timestamp: Date? {
      get {
        observationRegistrar.access(self, keyPath: \.timestamp)
        return timestampStorage
      }
      set {
        observationRegistrar.withMutation(of: self, keyPath: \.timestamp) {
          timestampStorage = newValue
        }
      }
    }

    func invalidate<Member>(_ keyPath: KeyPath<ObservationProbeObject, Member>) {
      observationRegistrar.withMutation(of: self, keyPath: keyPath) {}
    }

    func invalidateAllObservableKeyPaths() {
      invalidate(\.name)
      invalidate(\.timestamp)
    }
  }

  @available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *)
  private final class ObservationRelationshipProbeObject: Observable {
    private let observationRegistrar = ObservationRegistrar()
    private var childStorage: ObservationRelationshipProbeObject?
    private var childrenStorage: [ObservationRelationshipProbeObject] = []
    private var nameStorage: String

    init(name: String = "") {
      nameStorage = name
    }

    var name: String {
      get {
        observationRegistrar.access(self, keyPath: \.name)
        return nameStorage
      }
      set {
        observationRegistrar.withMutation(of: self, keyPath: \.name) {
          nameStorage = newValue
        }
      }
    }

    var child: ObservationRelationshipProbeObject? {
      get {
        observationRegistrar.access(self, keyPath: \.child)
        return childStorage
      }
      set {
        observationRegistrar.withMutation(of: self, keyPath: \.child) {
          childStorage = newValue
        }
      }
    }

    var children: [ObservationRelationshipProbeObject] {
      observationRegistrar.access(self, keyPath: \.children)
      return childrenStorage
    }

    var childrenCount: Int {
      observationRegistrar.access(self, keyPath: \.childrenCount)
      return childrenStorage.count
    }

    // Observation does not infer derived reads; count needs its own mutation event.
    func addChildWithGeneratedHelper(_ child: ObservationRelationshipProbeObject) {
      observationRegistrar.withMutation(of: self, keyPath: \.children) {
        childrenStorage.append(child)
      }
      observationRegistrar.withMutation(of: self, keyPath: \.childrenCount) {}
    }

    func addChildThroughStorageOnly(_ child: ObservationRelationshipProbeObject) {
      childrenStorage.append(child)
    }
  }

  private struct ObservationProfile: Equatable {
    var nickname: String
    var score: Int
  }

  @available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *)
  private final class ObservationCompositionProbe: Observable {
    private let observationRegistrar = ObservationRegistrar()
    private var profileStorage: ObservationProfile

    init(profile: ObservationProfile) {
      profileStorage = profile
    }

    var profile: ObservationProfile {
      get {
        observationRegistrar.access(self, keyPath: \.profile)
        return profileStorage
      }
      set {
        observationRegistrar.withMutation(of: self, keyPath: \.profile) {
          profileStorage = newValue
        }
      }
    }

    var nicknameLeaf: String {
      get {
        observationRegistrar.access(self, keyPath: \.nicknameLeaf)
        return profileStorage.nickname
      }
      set {
        observationRegistrar.withMutation(of: self, keyPath: \.nicknameLeaf) {
          profileStorage.nickname = newValue
        }
      }
    }

    func invalidate<Member>(_ keyPath: KeyPath<ObservationCompositionProbe, Member>) {
      observationRegistrar.withMutation(of: self, keyPath: keyPath) {}
    }
  }

  @available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *)
  @objc(CDEObservationSpikeItem)
  private final class ObservationSpikeItem: NSManagedObject, Observable {
    private let observationRegistrar = ObservationRegistrar()

    var name: String {
      get {
        observationRegistrar.access(self, keyPath: \.name)
        return value(forKey: "name") as? String ?? ""
      }
      set {
        observationRegistrar.withMutation(of: self, keyPath: \.name) {
          setValue(newValue, forKey: "name")
        }
      }
    }

    var timestamp: Date? {
      get {
        observationRegistrar.access(self, keyPath: \.timestamp)
        return value(forKey: "timestamp") as? Date
      }
      set {
        observationRegistrar.withMutation(of: self, keyPath: \.timestamp) {
          setValue(newValue, forKey: "timestamp")
        }
      }
    }

    func invalidate<Member>(_ keyPath: KeyPath<ObservationSpikeItem, Member>) {
      observationRegistrar.withMutation(of: self, keyPath: keyPath) {}
    }

    func invalidateAllObservableKeyPaths() {
      invalidate(\.name)
      invalidate(\.timestamp)
    }

    func writeNameThroughPrimitiveStorage(_ value: String) {
      willChangeValue(forKey: "name")
      setPrimitiveValue(value, forKey: "name")
      didChangeValue(forKey: "name")
    }
  }

  @available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *)
  @objc(CDEObservationDomainItem)
  private final class ObservationDomainItem: NSManagedObject, Observable {
    private let observationRegistrar = ObservationRegistrar()

    @MainActor
    var name: String {
      get {
        observationRegistrar.access(self, keyPath: \.name)
        CDEObservationGetterRuntime.registerObservedObjectIfNeeded(self)
        return value(forKey: "name") as? String ?? ""
      }
      set {
        setValue(newValue, forKey: "name")
      }
    }

    @MainActor
    func invalidateName() {
      observationRegistrar.withMutation(of: self, keyPath: \.name) {}
    }
  }

  // `withObservationTracking` calls `onChange` through a @Sendable closure, so the
  // test counter uses a lock instead of capturing actor-isolated mutable state.
  private final class ObservationChangeCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = 0

    var value: Int {
      lock.withLock { storage }
    }

    func increment() {
      lock.withLock {
        storage += 1
      }
    }
  }

  private final class WeakObservationTable<Object: AnyObject> {
    private struct Entry {
      weak var object: Object?
    }

    private var entries: [ObjectIdentifier: Entry] = [:]

    func register(_ object: Object) {
      entries[ObjectIdentifier(object)] = .init(object: object)
    }

    var liveCount: Int {
      entries = entries.filter { $0.value.object != nil }
      return entries.count
    }
  }

  private struct CoreDataChangeSnapshot: Equatable {
    var insertedObjectIDs: Set<String> = []
    var updatedObjectIDs: Set<String> = []
    var deletedObjectIDs: Set<String> = []
    var refreshedObjectIDs: Set<String> = []
    var invalidatedObjectIDs: Set<String> = []
    var changedKeysByObjectID: [String: Set<String>] = [:]
    var currentEventKeysByObjectID: [String: Set<String>] = [:]

    var affectedObjectIDs: Set<String> {
      insertedObjectIDs
        .union(updatedObjectIDs)
        .union(deletedObjectIDs)
        .union(refreshedObjectIDs)
        .union(invalidatedObjectIDs)
    }

    func keys(for object: NSManagedObject) -> Set<String> {
      changedKeysByObjectID[object.objectID.cdeObservationTestID] ?? []
    }

    func currentEventKeys(for object: NSManagedObject) -> Set<String> {
      currentEventKeysByObjectID[object.objectID.cdeObservationTestID] ?? []
    }
  }

  private final class CoreDataNotificationRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var tokens: [NSObjectProtocol] = []
    private var storage: [Notification.Name: [CoreDataChangeSnapshot]] = [:]
    private var notifications: [Notification.Name: [Notification]] = [:]

    init(context: NSManagedObjectContext, names: [Notification.Name]) {
      for name in names {
        let token = NotificationCenter.default.addObserver(
          forName: name,
          object: context,
          queue: nil
        ) { [weak self] notification in
          self?.record(notification)
        }
        tokens.append(token)
      }
    }

    deinit {
      for token in tokens {
        NotificationCenter.default.removeObserver(token)
      }
    }

    func reset() {
      lock.withLock {
        storage.removeAll()
        notifications.removeAll()
      }
    }

    func snapshots(for name: Notification.Name) -> [CoreDataChangeSnapshot] {
      lock.withLock { storage[name] ?? [] }
    }

    func lastNotification(for name: Notification.Name) -> Notification? {
      lock.withLock { notifications[name]?.last }
    }

    private func record(_ notification: Notification) {
      let snapshot = CoreDataChangeSnapshot(notification: notification)
      lock.withLock {
        storage[notification.name, default: []].append(snapshot)
        notifications[notification.name, default: []].append(notification)
      }
    }
  }

  private enum ObservationInvalidationDecision: Equatable {
    case exact(Set<String>)
    case allObservableKeyPaths
  }

  private enum ObservationInvalidationPlanner {
    static func decisions(
      affectedObjectIDs: Set<String>,
      pendingKeysByObjectID: [String: Set<String>]
    ) -> [String: ObservationInvalidationDecision] {
      Dictionary(
        uniqueKeysWithValues: affectedObjectIDs.map { objectID in
          if let keys = pendingKeysByObjectID[objectID], keys.isEmpty == false {
            return (objectID, .exact(keys))
          }
          return (objectID, .allObservableKeyPaths)
        }
      )
    }
  }

  private struct ObservationSaveHookKeyMap {
    var observableKeyPathsByCoreDataKey: [String: Set<String>]

    func observableKeyPaths(for coreDataKeys: Set<String>) -> Set<String> {
      coreDataKeys.reduce(into: []) { result, key in
        result.formUnion(observableKeyPathsByCoreDataKey[key] ?? [])
      }
    }
  }

  private enum ObservationAPIDiagnostic: Hashable {
    case requiresNSManagedObjectSubclass
    case requiresExplicitObjCEntityName
    case requiresSupportedObservationPlatform
    case requiresMainActorViewContextConsumer
  }

  private struct ObservationAPICandidate: Equatable {
    var spelling: String
    var keepsPersistentModelAsSingleSource: Bool
    var exposesMainActorBoundaryAtDeclaration: Bool
    var supportsMacroGeneratedStorageAndAccessors: Bool
    var requiresSecondaryRuntimeRegistration: Bool
    var diagnostics: Set<ObservationAPIDiagnostic>

    var mvpFitScore: Int {
      var score = 0
      if keepsPersistentModelAsSingleSource { score += 1 }
      if exposesMainActorBoundaryAtDeclaration { score += 1 }
      if supportsMacroGeneratedStorageAndAccessors { score += 1 }
      if requiresSecondaryRuntimeRegistration == false { score += 1 }
      if diagnostics.contains(.requiresSupportedObservationPlatform) { score += 1 }
      if diagnostics.contains(.requiresMainActorViewContextConsumer) { score += 1 }
      return score
    }
  }

  private enum ObservationAPIDraft {
    static let persistentModelParameter = ObservationAPICandidate(
      spelling: "@PersistentModel(observation: .mainActor)",
      keepsPersistentModelAsSingleSource: true,
      exposesMainActorBoundaryAtDeclaration: true,
      supportsMacroGeneratedStorageAndAccessors: true,
      requiresSecondaryRuntimeRegistration: false,
      diagnostics: requiredDiagnostics
    )

    static let standaloneMacro = ObservationAPICandidate(
      spelling: "@ObservablePersistentModel",
      keepsPersistentModelAsSingleSource: false,
      exposesMainActorBoundaryAtDeclaration: false,
      supportsMacroGeneratedStorageAndAccessors: true,
      requiresSecondaryRuntimeRegistration: false,
      diagnostics: requiredDiagnostics
    )

    static let markerRegistration = ObservationAPICandidate(
      spelling: "CDEObservablePersistentModel + helper registration",
      keepsPersistentModelAsSingleSource: false,
      exposesMainActorBoundaryAtDeclaration: false,
      supportsMacroGeneratedStorageAndAccessors: false,
      requiresSecondaryRuntimeRegistration: true,
      diagnostics: [.requiresMainActorViewContextConsumer]
    )

    static let candidates = [
      persistentModelParameter,
      standaloneMacro,
      markerRegistration,
    ]

    static var recommended: ObservationAPICandidate {
      candidates.max { lhs, rhs in lhs.mvpFitScore < rhs.mvpFitScore }!
    }

    private static let requiredDiagnostics: Set<ObservationAPIDiagnostic> = [
      .requiresNSManagedObjectSubclass,
      .requiresExplicitObjCEntityName,
      .requiresSupportedObservationPlatform,
      .requiresMainActorViewContextConsumer,
    ]
  }

  // Spike-only field identity: Core Data still reports string keys, but the hub can store
  // generated field IDs before dispatching to concrete key-path invalidation.
  private enum ObservationFieldID: UInt8, CaseIterable {
    case name
    case parent
    case children
    case childrenCount
    case orderedParent
    case orderedChildren
    case orderedChildrenCount
    case profile

    var swiftPath: String {
      switch self {
      case .name: return "name"
      case .parent: return "parent"
      case .children: return "children"
      case .childrenCount: return "childrenCount"
      case .orderedParent: return "orderedParent"
      case .orderedChildren: return "orderedChildren"
      case .orderedChildrenCount: return "orderedChildrenCount"
      case .profile: return "profile"
      }
    }
  }

  private struct ObservationFieldSet: Equatable {
    private(set) var rawBits: UInt64 = 0

    init(_ fields: [ObservationFieldID] = []) {
      for field in fields {
        insert(field)
      }
    }

    var isEmpty: Bool {
      rawBits == 0
    }

    var count: Int {
      rawBits.nonzeroBitCount
    }

    var swiftPaths: Set<String> {
      Set(fields.map(\.swiftPath))
    }

    var fields: [ObservationFieldID] {
      ObservationFieldID.allCases.filter { contains($0) }
    }

    mutating func insert(_ field: ObservationFieldID) {
      rawBits |= UInt64(1) << UInt64(field.rawValue)
    }

    func contains(_ field: ObservationFieldID) -> Bool {
      rawBits & (UInt64(1) << UInt64(field.rawValue)) != 0
    }

    func union(_ other: ObservationFieldSet) -> ObservationFieldSet {
      var result = self
      result.rawBits |= other.rawBits
      return result
    }
  }

  private struct ObservationFieldMap {
    var fieldsByCoreDataKey: [String: ObservationFieldSet]

    func fieldSet(for coreDataKeys: Set<String>) -> ObservationFieldSet {
      coreDataKeys.reduce(into: ObservationFieldSet()) { result, key in
        result = result.union(fieldsByCoreDataKey[key] ?? ObservationFieldSet())
      }
    }
  }

  private enum ObservationChangePayloadCost: Equatable {
    case fieldSet(ObservationFieldSet)
    case allObservableKeyPaths

    var storedFieldCount: Int {
      switch self {
      case .fieldSet(let fields):
        return fields.count
      case .allObservableKeyPaths:
        return 0
      }
    }
  }

  // Deterministic cost proxy for T20; wall-clock benchmarks should wait for real runtime code.
  private struct ObservationRouteCostPlan: Equatable {
    var lookupUnits: Int
    var pendingHistoryScanUnits: Int
    var relationshipTraversalUnits: Int
    var emittedMutationEvents: Int
    var payloadCost: ObservationChangePayloadCost

    static func merge(
      affectedObjectIDCount: Int,
      emittedObjectInvalidationCount: Int,
      payload: ObservationChangePayloadCost
    ) -> ObservationRouteCostPlan {
      ObservationRouteCostPlan(
        lookupUnits: affectedObjectIDCount,
        pendingHistoryScanUnits: 0,
        relationshipTraversalUnits: 0,
        emittedMutationEvents: emittedObjectInvalidationCount,
        payloadCost: payload
      )
    }
  }

  private struct ObservationSaveToken: Hashable, Sendable {
    private let id = UUID()
  }

  private enum ObservationPendingChange: Equatable {
    case keyPaths(Set<String>)
    case allObservableKeyPaths

    func merged(with other: ObservationPendingChange) -> ObservationPendingChange {
      switch (self, other) {
      case (.allObservableKeyPaths, _), (_, .allObservableKeyPaths):
        return .allObservableKeyPaths
      case (.keyPaths(let lhs), .keyPaths(let rhs)):
        return .keyPaths(lhs.union(rhs))
      }
    }

    var decision: ObservationInvalidationDecision {
      switch self {
      case .keyPaths(let keys):
        return .exact(keys)
      case .allObservableKeyPaths:
        return .allObservableKeyPaths
      }
    }
  }

  @MainActor
  // Spike buffer scoped to one viewContext/container; token contributions keep rollback precise
  // after multiple saves have merged keys for the same object.
  private final class ObservationChangeBuffer: @unchecked Sendable {
    private struct PendingObjectChange: Equatable {
      var change: ObservationPendingChange
      var tokens: Set<ObservationSaveToken>
    }

    private var pendingByObjectID: [String: PendingObjectChange] = [:]
    private var tokenIndex: [ObservationSaveToken: Set<String>] = [:]
    private var tokenContributions: [ObservationSaveToken: [String: ObservationPendingChange]] = [:]

    var pendingObjectCount: Int {
      pendingByObjectID.count
    }

    var tokenCount: Int {
      tokenIndex.count
    }

    func register(
      token: ObservationSaveToken,
      objectID: String,
      keys: Set<String>
    ) {
      guard keys.isEmpty == false else {
        return
      }

      register(token: token, objectID: objectID, change: .keyPaths(keys))
    }

    func pendingChange(for objectID: String) -> ObservationPendingChange? {
      pendingByObjectID[objectID]?.change
    }

    func consume(objectID: String) -> ObservationPendingChange? {
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

      return pending.change
    }

    func clear(objectID: String) {
      _ = consume(objectID: objectID)
    }

    func removeAll() {
      pendingByObjectID.removeAll()
      tokenIndex.removeAll()
      tokenContributions.removeAll()
    }

    func rollback(token: ObservationSaveToken) {
      guard let objectIDs = tokenIndex.removeValue(forKey: token) else {
        return
      }
      tokenContributions.removeValue(forKey: token)

      for objectID in objectIDs {
        guard var pending = pendingByObjectID[objectID] else {
          continue
        }
        pending.tokens.remove(token)
        if let rebuilt = rebuildChange(for: objectID, tokens: pending.tokens) {
          pending.change = rebuilt
          pendingByObjectID[objectID] = pending
        } else {
          pendingByObjectID.removeValue(forKey: objectID)
        }
      }
    }

    func compress(objectID: String) {
      guard var pending = pendingByObjectID[objectID] else {
        return
      }
      pending.change = .allObservableKeyPaths
      pendingByObjectID[objectID] = pending

      for token in pending.tokens {
        tokenContributions[token]?[objectID] = .allObservableKeyPaths
      }
    }

    private func register(
      token: ObservationSaveToken,
      objectID: String,
      change: ObservationPendingChange
    ) {
      tokenIndex[token, default: []].insert(objectID)
      tokenContributions[token, default: [:]][objectID] = change

      if var pending = pendingByObjectID[objectID] {
        pending.change = pending.change.merged(with: change)
        pending.tokens.insert(token)
        pendingByObjectID[objectID] = pending
      } else {
        pendingByObjectID[objectID] = .init(change: change, tokens: [token])
      }
    }

    private func rebuildChange(
      for objectID: String,
      tokens: Set<ObservationSaveToken>
    ) -> ObservationPendingChange? {
      tokens
        .compactMap { tokenContributions[$0]?[objectID] }
        .reduce(nil) { partial, change in
          partial?.merged(with: change) ?? change
        }
    }
  }

  private final class ObservationEventLog: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []

    var events: [String] {
      lock.withLock { storage }
    }

    func append(_ event: String) {
      lock.withLock {
        storage.append(event)
      }
    }

    func firstIndex(of event: String) -> Int? {
      lock.withLock { storage.firstIndex(of: event) }
    }
  }

  private final class ObservationNotificationEventRecorder {
    private let token: NSObjectProtocol
    let isObserving = true

    init(
      context: NSManagedObjectContext,
      name: Notification.Name,
      eventLog: ObservationEventLog,
      event: String
    ) {
      token = NotificationCenter.default.addObserver(
        forName: name,
        object: context,
        queue: nil
      ) { _ in
        eventLog.append(event)
      }
    }

    deinit {
      NotificationCenter.default.removeObserver(token)
    }
  }

  private struct ObservationContextProducerID: Hashable, Sendable {
    private let id = UUID()
  }

  private struct ObservationStagedContextSave: Equatable {
    var token: ObservationSaveToken
    var changesByObjectID: [String: Set<String>]
  }

  private struct ObservationRegisteredPendingObjectChange: Equatable {
    var change: ObservationPendingChange
    var tokens: Set<ObservationSaveToken>
  }

  private final class ObservationRegisteredContextDomain: @unchecked Sendable {
    private let lock = NSLock()
    private var stagedByProducerID: [ObservationContextProducerID: ObservationStagedContextSave] =
      [:]
    private var pendingByObjectID: [String: ObservationRegisteredPendingObjectChange] = [:]
    private var tokenIndex: [ObservationSaveToken: Set<String>] = [:]
    private var tokenContributions: [ObservationSaveToken: [String: ObservationPendingChange]] = [:]
    private var tokensByProducerID: [ObservationContextProducerID: Set<ObservationSaveToken>] = [:]

    var pendingObjectCount: Int {
      lock.withLock { pendingByObjectID.count }
    }

    var tokenCount: Int {
      lock.withLock { tokenIndex.count }
    }

    var stagedSaveCount: Int {
      lock.withLock { stagedByProducerID.count }
    }

    func stage(
      producerID: ObservationContextProducerID,
      token: ObservationSaveToken,
      changesByObjectID: [String: Set<String>]
    ) {
      lock.withLock {
        guard changesByObjectID.isEmpty == false else {
          stagedByProducerID.removeValue(forKey: producerID)
          return
        }

        stagedByProducerID[producerID] = .init(
          token: token,
          changesByObjectID: changesByObjectID
        )
      }
    }

    func commitStagedSave(producerID: ObservationContextProducerID) -> Bool {
      lock.withLock {
        guard let staged = stagedByProducerID.removeValue(forKey: producerID) else {
          return false
        }

        for (objectID, keys) in staged.changesByObjectID where keys.isEmpty == false {
          registerLocked(token: staged.token, objectID: objectID, change: .keyPaths(keys))
        }

        tokensByProducerID[producerID, default: []].insert(staged.token)
        return true
      }
    }

    func discardStagedSave(producerID: ObservationContextProducerID) {
      _ = lock.withLock {
        stagedByProducerID.removeValue(forKey: producerID)
      }
    }

    func unregisterProducer(_ producerID: ObservationContextProducerID) {
      lock.withLock {
        stagedByProducerID.removeValue(forKey: producerID)
        let tokens = tokensByProducerID.removeValue(forKey: producerID) ?? []
        for token in tokens {
          rollbackLocked(token: token)
        }
      }
    }

    func pendingChange(for objectID: String) -> ObservationPendingChange? {
      lock.withLock { pendingByObjectID[objectID]?.change }
    }

    func consume(objectID: String) -> ObservationPendingChange? {
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

        return pending.change
      }
    }

    func pendingKeysSnapshot() -> [String: Set<String>] {
      lock.withLock {
        pendingByObjectID.compactMapValues { pending in
          if case .keyPaths(let keys) = pending.change {
            return keys
          }
          return nil
        }
      }
    }

    private func registerLocked(
      token: ObservationSaveToken,
      objectID: String,
      change: ObservationPendingChange
    ) {
      tokenIndex[token, default: []].insert(objectID)
      tokenContributions[token, default: [:]][objectID] = change

      if var pending = pendingByObjectID[objectID] {
        pending.change = pending.change.merged(with: change)
        pending.tokens.insert(token)
        pendingByObjectID[objectID] = pending
      } else {
        pendingByObjectID[objectID] = .init(change: change, tokens: [token])
      }
    }

    private func rollbackLocked(token: ObservationSaveToken) {
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
          pending.change = rebuilt
          pendingByObjectID[objectID] = pending
        } else {
          pendingByObjectID.removeValue(forKey: objectID)
        }
      }
    }

    private func rebuildChangeLocked(
      for objectID: String,
      tokens: Set<ObservationSaveToken>
    ) -> ObservationPendingChange? {
      tokens
        .compactMap { tokenContributions[$0]?[objectID] }
        .reduce(nil) { partial, change in
          partial?.merged(with: change) ?? change
        }
    }
  }

  // Registered direct-save metadata is staged during willSave and promoted only after didSave.
  // That keeps failed saves invisible to merge routing while preserving pre-merge ordering.
  private final class ObservationRegisteredContextProducer: @unchecked Sendable {
    private let producerID = ObservationContextProducerID()
    private let context: NSManagedObjectContext
    private let domain: ObservationRegisteredContextDomain
    private let eventLog: ObservationEventLog?
    private let metadataEvent: String
    private let lock = NSLock()
    private var tokens: [NSObjectProtocol] = []
    private var observing = true

    var isObserving: Bool {
      lock.withLock { observing }
    }

    init(
      context: NSManagedObjectContext,
      domain: ObservationRegisteredContextDomain,
      eventLog: ObservationEventLog? = nil,
      metadataEvent: String = "metadata"
    ) {
      self.context = context
      self.domain = domain
      self.eventLog = eventLog
      self.metadataEvent = metadataEvent

      tokens = [
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
        ) { [weak self] _ in
          self?.commitSave()
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

    deinit {
      invalidate()
    }

    func invalidate() {
      let observerTokens = lock.withLock {
        guard observing else {
          return [NSObjectProtocol]()
        }

        observing = false
        let observerTokens = tokens
        tokens.removeAll()
        return observerTokens
      }

      for token in observerTokens {
        NotificationCenter.default.removeObserver(token)
      }

      domain.unregisterProducer(producerID)
    }

    private func stageSave(from notification: Notification) {
      guard notification.object as? NSManagedObjectContext === context else {
        return
      }

      let changes = collectUpdatedObjectKeys()
      domain.stage(
        producerID: producerID,
        token: ObservationSaveToken(),
        changesByObjectID: changes
      )
    }

    private func commitSave() {
      if domain.commitStagedSave(producerID: producerID) {
        eventLog?.append(metadataEvent)
      }
    }

    private func handleObjectsDidChange(_ notification: Notification) {
      if notification.userInfo?[NSInvalidatedAllObjectsKey] != nil {
        domain.unregisterProducer(producerID)
      } else {
        domain.discardStagedSave(producerID: producerID)
      }
    }

    private func collectUpdatedObjectKeys() -> [String: Set<String>] {
      context.updatedObjects.reduce(into: [:]) { result, object in
        guard object.objectID.isTemporaryID == false else {
          return
        }

        let keys = object.cdeObservationPendingKeys
        guard keys.isEmpty == false else {
          return
        }

        result[object.objectID.cdeObservationTestID, default: []].formUnion(keys)
      }
    }
  }

  @objc(CDEObservationChangeParent)
  private final class ObservationChangeParent: NSManagedObject {
    var ignoredNote = ""
  }

  @objc(CDEObservationChangeChild)
  private final class ObservationChangeChild: NSManagedObject {}

  @objc(CDEObservationOrderedChild)
  private final class ObservationOrderedChild: NSManagedObject {}

  private struct ObservationChangeHarness {
    let container: NSPersistentContainer
    let context: NSManagedObjectContext
    let parent: ObservationChangeParent
    let secondParent: ObservationChangeParent
    let child: ObservationChangeChild
    let orderedChild: ObservationOrderedChild
  }

  @available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *)
  private final class ObservationObjectIDTable<Object: NSManagedObject> {
    private struct Entry {
      weak var object: Object?
    }

    private var entries: [NSManagedObjectID: Entry] = [:]

    func register(_ object: Object) {
      entries[object.objectID] = .init(object: object)
    }

    func rekey(_ object: Object, from oldID: NSManagedObjectID) {
      entries.removeValue(forKey: oldID)
      entries[object.objectID] = .init(object: object)
    }

    func object(for objectID: NSManagedObjectID) -> Object? {
      guard let object = entries[objectID]?.object else {
        entries.removeValue(forKey: objectID)
        return nil
      }
      return object
    }

    func contains(_ objectID: NSManagedObjectID) -> Bool {
      object(for: objectID) != nil
    }

    func unregister(_ objectID: NSManagedObjectID) {
      entries.removeValue(forKey: objectID)
    }

    func removeAll() {
      entries.removeAll()
    }

    var liveObjectIDs: Set<NSManagedObjectID> {
      entries = entries.filter { $0.value.object != nil }
      return Set(entries.keys)
    }
  }

  @MainActor
  @available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *)
  private final class CDEObservationDomainSkeleton {
    private let viewContext: NSManagedObjectContext
    private let observedObjects = ObservationObjectIDTable<NSManagedObject>()
    private let producerMetadata = ObservationRegisteredContextDomain()
    private var producerRegistrations: [ObservationRegisteredContextProducer] = []
    private var isActive = true

    init(container: NSPersistentContainer) {
      viewContext = container.viewContext
      CDEObservationDomainRegistry.activate(self, for: viewContext)
    }

    deinit {
      // The spike creates and releases domains on MainActor; deinit mirrors explicit cleanup.
      MainActor.assumeIsolated {
        invalidate()
      }
    }

    var liveObservedObjectIDs: Set<NSManagedObjectID> {
      observedObjects.liveObjectIDs
    }

    var pendingObjectCount: Int {
      producerMetadata.pendingObjectCount
    }

    func registerChangeProducer(
      context: NSManagedObjectContext
    ) -> ObservationRegisteredContextProducer {
      let producer = ObservationRegisteredContextProducer(
        context: context,
        domain: producerMetadata
      )
      producerRegistrations.append(producer)
      return producer
    }

    func registerObservedObject(_ object: NSManagedObject) {
      guard isActive, object.managedObjectContext === viewContext else {
        return
      }

      observedObjects.register(object)
    }

    func containsObservedObject(_ objectID: NSManagedObjectID) -> Bool {
      observedObjects.contains(objectID)
    }

    func pendingChange(for objectID: String) -> ObservationPendingChange? {
      producerMetadata.pendingChange(for: objectID)
    }

    func invalidate() {
      guard isActive else {
        return
      }

      isActive = false
      for producer in producerRegistrations {
        producer.invalidate()
      }
      producerRegistrations.removeAll()
      observedObjects.removeAll()
      CDEObservationDomainRegistry.deactivate(self, for: viewContext)
    }
  }

  @MainActor
  @available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *)
  private enum CDEObservationDomainRegistry {
    private final class WeakDomain {
      weak var domain: CDEObservationDomainSkeleton?

      init(_ domain: CDEObservationDomainSkeleton) {
        self.domain = domain
      }
    }

    private static var domainsByContextID: [ObjectIdentifier: WeakDomain] = [:]

    static func activate(
      _ domain: CDEObservationDomainSkeleton,
      for viewContext: NSManagedObjectContext
    ) {
      domainsByContextID[ObjectIdentifier(viewContext)] = WeakDomain(domain)
    }

    static func domain(for context: NSManagedObjectContext) -> CDEObservationDomainSkeleton? {
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

    static func deactivate(
      _ domain: CDEObservationDomainSkeleton,
      for viewContext: NSManagedObjectContext
    ) {
      let contextID = ObjectIdentifier(viewContext)
      guard domainsByContextID[contextID]?.domain === domain else {
        return
      }

      domainsByContextID.removeValue(forKey: contextID)
    }
  }

  @MainActor
  @available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *)
  private enum CDEObservationGetterRuntime {
    // Generated getters use the object's viewContext association; users do not register objects.
    static func registerObservedObjectIfNeeded(_ object: NSManagedObject) {
      guard let context = object.managedObjectContext else {
        return
      }

      CDEObservationDomainRegistry.domain(for: context)?.registerObservedObject(object)
    }
  }

  private struct ObservationHubLookupPlan: Equatable {
    var invalidations: [String: ObservationInvalidationDecision]
    var lookupCount: Int
  }

  // Merge handling is bounded by the incoming objectIDs: consume pending metadata for those
  // objects, then notify only live instances that were actually observed by SwiftUI.
  @MainActor
  @available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *)
  private enum ObservationHubSelector {
    static func plan<Object: NSManagedObject>(
      affectedObjectIDs: [NSManagedObjectID],
      observedObjects: ObservationObjectIDTable<Object>,
      buffer: ObservationChangeBuffer
    ) -> ObservationHubLookupPlan {
      var invalidations: [String: ObservationInvalidationDecision] = [:]
      var lookupCount = 0

      for objectID in affectedObjectIDs {
        lookupCount += 1
        let testID = objectID.cdeObservationTestID
        let pendingChange = buffer.consume(objectID: testID)

        guard observedObjects.object(for: objectID) != nil else {
          continue
        }

        invalidations[testID] = pendingChange?.decision ?? .allObservableKeyPaths
      }

      return .init(invalidations: invalidations, lookupCount: lookupCount)
    }
  }

  @MainActor
  @available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *)
  private enum ObservationLifecycleHub {
    static func refreshOrInvalidate<Object: NSManagedObject>(
      affectedObjectIDs: [NSManagedObjectID],
      observedObjects: ObservationObjectIDTable<Object>,
      buffer: ObservationChangeBuffer
    ) -> ObservationHubLookupPlan {
      allKeyInvalidationPlan(
        affectedObjectIDs: affectedObjectIDs,
        observedObjects: observedObjects,
        buffer: buffer
      )
    }

    static func rollback<Object: NSManagedObject>(
      affectedObjectIDs: [NSManagedObjectID],
      observedObjects: ObservationObjectIDTable<Object>,
      buffer: ObservationChangeBuffer,
      tokens: [ObservationSaveToken]
    ) -> ObservationHubLookupPlan {
      for token in tokens {
        buffer.rollback(token: token)
      }

      return allKeyInvalidationPlan(
        affectedObjectIDs: affectedObjectIDs,
        observedObjects: observedObjects,
        buffer: buffer
      )
    }

    static func delete<Object: NSManagedObject>(
      objectIDs: [NSManagedObjectID],
      observedObjects: ObservationObjectIDTable<Object>,
      buffer: ObservationChangeBuffer
    ) {
      for objectID in objectIDs {
        observedObjects.unregister(objectID)
        buffer.clear(objectID: objectID.cdeObservationTestID)
      }
    }

    static func reset<Object: NSManagedObject>(
      observedObjects: ObservationObjectIDTable<Object>,
      buffer: ObservationChangeBuffer
    ) {
      observedObjects.removeAll()
      buffer.removeAll()
    }

    private static func allKeyInvalidationPlan<Object: NSManagedObject>(
      affectedObjectIDs: [NSManagedObjectID],
      observedObjects: ObservationObjectIDTable<Object>,
      buffer: ObservationChangeBuffer
    ) -> ObservationHubLookupPlan {
      var invalidations: [String: ObservationInvalidationDecision] = [:]
      var lookupCount = 0

      for objectID in affectedObjectIDs {
        lookupCount += 1
        let testID = objectID.cdeObservationTestID
        buffer.clear(objectID: testID)

        guard observedObjects.object(for: objectID) != nil else {
          continue
        }

        invalidations[testID] = .allObservableKeyPaths
      }

      return .init(invalidations: invalidations, lookupCount: lookupCount)
    }
  }

  private enum ObservationChangeModel {
    static let parentEntityName = "CDEObservationChangeParent"
    static let childEntityName = "CDEObservationChangeChild"
    static let orderedChildEntityName = "CDEObservationOrderedChild"

    @MainActor
    static let model: NSManagedObjectModel = {
      let model = NSManagedObjectModel()

      let parentEntity = NSEntityDescription()
      parentEntity.name = parentEntityName
      parentEntity.managedObjectClassName = NSStringFromClass(ObservationChangeParent.self)

      let childEntity = NSEntityDescription()
      childEntity.name = childEntityName
      childEntity.managedObjectClassName = NSStringFromClass(ObservationChangeChild.self)

      let orderedChildEntity = NSEntityDescription()
      orderedChildEntity.name = orderedChildEntityName
      orderedChildEntity.managedObjectClassName = NSStringFromClass(ObservationOrderedChild.self)

      let parentName = stringAttribute("name", optional: false)
      let parentProfileStorage = stringAttribute("profileStorage", optional: true)
      let parentTransient = stringAttribute("transientNote", optional: true)
      parentTransient.isTransient = true

      let childName = stringAttribute("name", optional: false)
      let orderedChildName = stringAttribute("name", optional: false)

      let children = NSRelationshipDescription()
      children.name = "children"
      children.destinationEntity = childEntity
      children.deleteRule = .nullifyDeleteRule
      children.minCount = 0
      children.maxCount = 0
      children.isOptional = true

      let parent = NSRelationshipDescription()
      parent.name = "parent"
      parent.destinationEntity = parentEntity
      parent.deleteRule = .nullifyDeleteRule
      parent.minCount = 0
      parent.maxCount = 1
      parent.isOptional = true
      parent.inverseRelationship = children
      children.inverseRelationship = parent

      let orderedChildren = NSRelationshipDescription()
      orderedChildren.name = "orderedChildren"
      orderedChildren.destinationEntity = orderedChildEntity
      orderedChildren.deleteRule = .nullifyDeleteRule
      orderedChildren.minCount = 0
      orderedChildren.maxCount = 0
      orderedChildren.isOptional = true
      orderedChildren.isOrdered = true

      let orderedParent = NSRelationshipDescription()
      orderedParent.name = "orderedParent"
      orderedParent.destinationEntity = parentEntity
      orderedParent.deleteRule = .nullifyDeleteRule
      orderedParent.minCount = 0
      orderedParent.maxCount = 1
      orderedParent.isOptional = true
      orderedParent.inverseRelationship = orderedChildren
      orderedChildren.inverseRelationship = orderedParent

      parentEntity.properties = [
        parentName,
        parentProfileStorage,
        parentTransient,
        children,
        orderedChildren,
      ]
      childEntity.properties = [childName, parent]
      orderedChildEntity.properties = [orderedChildName, orderedParent]
      model.entities = [parentEntity, childEntity, orderedChildEntity]
      return model
    }()

    @MainActor
    static func makeContainer(
      testName: String,
      automaticallyMergesChangesFromParent: Bool = true
    ) throws -> NSPersistentContainer {
      let container = try NSPersistentContainer.makeTest(
        model: model,
        testName: testName
      )
      container.viewContext.automaticallyMergesChangesFromParent =
        automaticallyMergesChangesFromParent
      return container
    }

    @MainActor
    static func makeHarness(
      testName: String,
      automaticallyMergesChangesFromParent: Bool = true
    ) throws -> ObservationChangeHarness {
      let container = try makeContainer(
        testName: testName,
        automaticallyMergesChangesFromParent: automaticallyMergesChangesFromParent
      )
      let context = container.viewContext
      let parent = try makeParent(in: context, name: "parent")
      let secondParent = try makeParent(in: context, name: "second")
      let child = try makeChild(in: context, name: "child")
      let orderedChild = try makeOrderedChild(in: context, name: "ordered")
      try context.save()
      return .init(
        container: container,
        context: context,
        parent: parent,
        secondParent: secondParent,
        child: child,
        orderedChild: orderedChild
      )
    }

    static func makeParent(
      in context: NSManagedObjectContext,
      name: String
    ) throws -> ObservationChangeParent {
      let parent = try insert(
        entityName: parentEntityName,
        in: context,
        as: ObservationChangeParent.self
      )
      parent.setValue(name, forKey: "name")
      return parent
    }

    static func makeChild(
      in context: NSManagedObjectContext,
      name: String
    ) throws -> ObservationChangeChild {
      let child = try insert(
        entityName: childEntityName,
        in: context,
        as: ObservationChangeChild.self
      )
      child.setValue(name, forKey: "name")
      return child
    }

    static func makeOrderedChild(
      in context: NSManagedObjectContext,
      name: String
    ) throws -> ObservationOrderedChild {
      let child = try insert(
        entityName: orderedChildEntityName,
        in: context,
        as: ObservationOrderedChild.self
      )
      child.setValue(name, forKey: "name")
      return child
    }

    private static func insert<Object: NSManagedObject>(
      entityName: String,
      in context: NSManagedObjectContext,
      as type: Object.Type
    ) throws -> Object {
      let entity = try #require(NSEntityDescription.entity(forEntityName: entityName, in: context))
      return Object(entity: entity, insertInto: context)
    }

    private static func stringAttribute(
      _ name: String,
      optional: Bool
    ) -> NSAttributeDescription {
      let attribute = NSAttributeDescription()
      attribute.name = name
      attribute.attributeType = .stringAttributeType
      attribute.isOptional = optional
      return attribute
    }
  }

  @NSModelActor(disableGenerateInit: true)
  private actor ObservationMetadataActor {
    init(container: NSPersistentContainer, contextName: String = "ObservationMetadataActor") {
      modelContainer = container
      let context = container.newBackgroundContext()
      context.name = contextName
      modelExecutor = .init(context: context)
    }

    func updateParentNameWithObservedSave(
      id: NSManagedObjectID,
      newName: String,
      buffer: ObservationChangeBuffer,
      eventLog: ObservationEventLog? = nil
    ) async throws -> ObservationSaveToken {
      let parent = try modelContext.existingObject(with: id)
      parent.setValue(newName, forKey: "name")
      return try await saveObservedChanges(buffer: buffer, eventLog: eventLog)
    }

    func updateParentNameWithFailingObservedSave(
      id: NSManagedObjectID,
      buffer: ObservationChangeBuffer
    ) async throws {
      let parent = try modelContext.existingObject(with: id)
      parent.setValue(nil, forKey: "name")
      _ = try await saveObservedChanges(buffer: buffer, eventLog: nil)
    }

    func updateParentNameWithDirectSave(
      id: NSManagedObjectID,
      newName: String
    ) throws {
      let parent = try modelContext.existingObject(with: id)
      parent.setValue(newName, forKey: "name")
      try modelContext.save()
    }

    func insertParentWithObservedSave(
      name: String,
      buffer: ObservationChangeBuffer
    ) async throws -> NSManagedObjectID {
      let parent = try ObservationChangeModel.makeParent(in: modelContext, name: name)
      _ = try await saveObservedChanges(buffer: buffer, eventLog: nil)
      return parent.objectID
    }

    func insertChildAttachedToParentWithObservedSave(
      parentID: NSManagedObjectID,
      childName: String,
      buffer: ObservationChangeBuffer
    ) async throws -> NSManagedObjectID {
      let parent = try modelContext.existingObject(with: parentID)
      let child = try ObservationChangeModel.makeChild(in: modelContext, name: childName)
      child.setValue(parent, forKey: "parent")
      _ = try await saveObservedChanges(buffer: buffer, eventLog: nil)
      return child.objectID
    }

    private func saveObservedChanges(
      buffer: ObservationChangeBuffer,
      eventLog: ObservationEventLog?
    ) async throws -> ObservationSaveToken {
      let token = ObservationSaveToken()
      let pendingChanges = collectUpdatedObjectKeys()

      // Metadata must be visible to the MainActor side before save notifications can merge.
      for (objectID, keys) in pendingChanges {
        await buffer.register(token: token, objectID: objectID, keys: keys)
      }
      eventLog?.append("metadata")

      do {
        try modelContext.save()
        eventLog?.append("save")
        return token
      } catch {
        await buffer.rollback(token: token)
        modelContext.rollback()
        throw error
      }
    }

    private func collectUpdatedObjectKeys() -> [String: Set<String>] {
      modelContext.updatedObjects.reduce(into: [:]) { result, object in
        guard object.objectID.isTemporaryID == false else {
          return
        }

        let keys = object.cdeObservationPendingKeys
        guard keys.isEmpty == false else {
          return
        }

        result[object.objectID.cdeObservationTestID, default: []].formUnion(keys)
      }
    }
  }

  @MainActor
  @available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *)
  private enum ObservationSpikeModel {
    static let itemEntityName = "CDEObservationSpikeItem"
    static let domainEntityName = "CDEObservationDomainItem"

    static let model: NSManagedObjectModel = {
      let model = NSManagedObjectModel()
      let entity = NSEntityDescription()
      entity.name = itemEntityName
      entity.managedObjectClassName = NSStringFromClass(ObservationSpikeItem.self)

      let name = NSAttributeDescription()
      name.name = "name"
      name.attributeType = .stringAttributeType
      name.isOptional = false

      let timestamp = NSAttributeDescription()
      timestamp.name = "timestamp"
      timestamp.attributeType = .dateAttributeType
      timestamp.isOptional = true

      let domainEntity = NSEntityDescription()
      domainEntity.name = domainEntityName
      domainEntity.managedObjectClassName = NSStringFromClass(ObservationDomainItem.self)

      let domainName = NSAttributeDescription()
      domainName.name = "name"
      domainName.attributeType = .stringAttributeType
      domainName.isOptional = false

      entity.properties = [name, timestamp]
      domainEntity.properties = [domainName]
      model.entities = [entity, domainEntity]
      return model
    }()

    static func makeContainer(testName: String) throws -> NSPersistentContainer {
      let container = try NSPersistentContainer.makeTest(
        model: model,
        testName: testName
      )
      container.viewContext.automaticallyMergesChangesFromParent = true
      return container
    }

    static func makeItem(in context: NSManagedObjectContext) throws -> ObservationSpikeItem {
      let entity = try #require(
        NSEntityDescription.entity(
          forEntityName: itemEntityName,
          in: context
        ))
      return ObservationSpikeItem(entity: entity, insertInto: context)
    }

    static func makeDomainItem(in context: NSManagedObjectContext) throws -> ObservationDomainItem {
      let entity = try #require(
        NSEntityDescription.entity(
          forEntityName: domainEntityName,
          in: context
        ))
      return ObservationDomainItem(entity: entity, insertInto: context)
    }
  }

  extension CoreDataChangeSnapshot {
    fileprivate init(notification: Notification) {
      let userInfo = notification.userInfo
      let willSaveContext =
        notification.name == Notification.Name.NSManagedObjectContextWillSave
        ? notification.object as? NSManagedObjectContext
        : nil
      insertedObjectIDs = Self.objectIDs(
        from: userInfo,
        objectKey: NSInsertedObjectsKey,
        objectIDKey: NSInsertedObjectIDsKey
      )
      updatedObjectIDs = Self.objectIDs(
        from: userInfo,
        objectKey: NSUpdatedObjectsKey,
        objectIDKey: NSUpdatedObjectIDsKey
      )
      deletedObjectIDs = Self.objectIDs(
        from: userInfo,
        objectKey: NSDeletedObjectsKey,
        objectIDKey: NSDeletedObjectIDsKey
      )
      refreshedObjectIDs = Self.objectIDs(
        from: userInfo,
        objectKey: NSRefreshedObjectsKey,
        objectIDKey: NSRefreshedObjectIDsKey
      )
      invalidatedObjectIDs = Self.objectIDs(
        from: userInfo,
        objectKey: NSInvalidatedObjectsKey,
        objectIDKey: NSInvalidatedObjectIDsKey
      )
      if let willSaveContext {
        insertedObjectIDs.formUnion(
          willSaveContext.insertedObjects.map(\.objectID.cdeObservationTestID))
        updatedObjectIDs.formUnion(
          willSaveContext.updatedObjects.map(\.objectID.cdeObservationTestID))
        deletedObjectIDs.formUnion(
          willSaveContext.deletedObjects.map(\.objectID.cdeObservationTestID))
      }

      var changedObjects = Self.objects(
        from: userInfo,
        keys: [
          NSInsertedObjectsKey,
          NSUpdatedObjectsKey,
          NSDeletedObjectsKey,
          NSRefreshedObjectsKey,
          NSInvalidatedObjectsKey,
        ]
      )
      if let willSaveContext {
        changedObjects.append(contentsOf: willSaveContext.insertedObjects)
        changedObjects.append(contentsOf: willSaveContext.updatedObjects)
        changedObjects.append(contentsOf: willSaveContext.deletedObjects)
      }

      changedKeysByObjectID = Self.keyMap(for: changedObjects) {
        Set($0.changedValues().keys)
      }
      currentEventKeysByObjectID = Self.keyMap(for: changedObjects) {
        Set($0.changedValuesForCurrentEvent().keys)
      }
    }

    private static func objectIDs(
      from userInfo: [AnyHashable: Any]?,
      objectKey: String,
      objectIDKey: String
    ) -> Set<String> {
      var objectIDs = Set<String>()

      for object in objects(from: userInfo, keys: [objectKey]) {
        objectIDs.insert(object.objectID.cdeObservationTestID)
      }

      if let values = userInfo?[objectIDKey] as? Set<NSManagedObjectID> {
        objectIDs.formUnion(values.map(\.cdeObservationTestID))
      }

      if let values = userInfo?[objectIDKey] as? [NSManagedObjectID] {
        objectIDs.formUnion(values.map(\.cdeObservationTestID))
      }

      return objectIDs
    }

    private static func objects(
      from userInfo: [AnyHashable: Any]?,
      keys: [String]
    ) -> [NSManagedObject] {
      keys.flatMap { key in
        if let values = userInfo?[key] as? Set<NSManagedObject> {
          return Array(values)
        }
        if let values = userInfo?[key] as? [NSManagedObject] {
          return values
        }
        return []
      }
    }

    private static func keyMap(
      for objects: [NSManagedObject],
      keys: (NSManagedObject) -> Set<String>
    ) -> [String: Set<String>] {
      objects.reduce(into: [:]) { result, object in
        result[object.objectID.cdeObservationTestID, default: []].formUnion(keys(object))
      }
    }
  }

  extension NSManagedObject {
    fileprivate var cdeObservationPendingKeys: Set<String> {
      Set(changedValues().keys)
    }

    fileprivate var cdeObservationCurrentEventKeys: Set<String> {
      Set(changedValuesForCurrentEvent().keys)
    }
  }

  extension NSManagedObjectID {
    fileprivate var cdeObservationTestID: String {
      uriRepresentation().absoluteString
    }
  }

  extension ObservationSaveHookKeyMap {
    fileprivate static let mvp = ObservationSaveHookKeyMap(
      observableKeyPathsByCoreDataKey: [
        "name": ["name"],
        "parent": ["parent"],
        "children": ["children", "childrenCount"],
        "orderedParent": ["orderedParent"],
        "orderedChildren": ["orderedChildren", "orderedChildrenCount"],
        "profileStorage": ["profile"],
      ]
    )
  }

  extension ObservationFieldMap {
    fileprivate static let mvp = ObservationFieldMap(
      fieldsByCoreDataKey: [
        "name": ObservationFieldSet([.name]),
        "parent": ObservationFieldSet([.parent]),
        "children": ObservationFieldSet([.children, .childrenCount]),
        "orderedParent": ObservationFieldSet([.orderedParent]),
        "orderedChildren": ObservationFieldSet([.orderedChildren, .orderedChildrenCount]),
        "profileStorage": ObservationFieldSet([.profile]),
      ]
    )
  }

  @Suite("Observation Spike")
  struct ObservationSpikeTests {
    @Test("T01 external registrar invalidation is property scoped")
    func externalRegistrarInvalidationIsPropertyScoped() {
      guard #available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *) else {
        return
      }

      let object = ObservationProbeObject()
      let counter = ObservationChangeCounter()

      _ = withObservationTracking {
        object.name
      } onChange: {
        counter.increment()
      }

      object.invalidate(\.timestamp)
      #expect(counter.value == 0)

      object.invalidate(\.name)
      #expect(counter.value == 1)
    }

    @Test("T01 all-key fallback reaches a tracked property")
    func allKeyFallbackReachesTrackedProperty() {
      guard #available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *) else {
        return
      }

      let object = ObservationProbeObject()
      let counter = ObservationChangeCounter()

      _ = withObservationTracking {
        object.name
      } onChange: {
        counter.increment()
      }

      object.invalidateAllObservableKeyPaths()
      #expect(counter.value == 1)
    }

    @Test("T02 availability-gated Observation helper compiles without changing package platforms")
    func availabilityGatedObservationHelperCompiles() {
      guard #available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *) else {
        return
      }

      let object = ObservationProbeObject()
      object.name = "available"
      #expect(object.name == "available")
    }

    @Test("T03 opt-in API draft keeps PersistentModel as the declaration site")
    func optInAPIDraftKeepsPersistentModelAsDeclarationSite() {
      let recommended = ObservationAPIDraft.recommended

      #expect(recommended.spelling == "@PersistentModel(observation: .mainActor)")
      #expect(recommended.keepsPersistentModelAsSingleSource)
      #expect(recommended.exposesMainActorBoundaryAtDeclaration)
      #expect(recommended.supportsMacroGeneratedStorageAndAccessors)
      #expect(recommended.requiresSecondaryRuntimeRegistration == false)
      #expect(
        recommended.mvpFitScore > ObservationAPIDraft.standaloneMacro.mvpFitScore
      )
      #expect(
        recommended.mvpFitScore > ObservationAPIDraft.markerRegistration.mvpFitScore
      )
      #expect(
        recommended.diagnostics == [
          .requiresNSManagedObjectSubclass,
          .requiresExplicitObjCEntityName,
          .requiresSupportedObservationPlatform,
          .requiresMainActorViewContextConsumer,
        ]
      )
    }

    @MainActor
    @Test("T04 registrar storage survives Core Data lifecycle events")
    func registrarStorageSurvivesCoreDataLifecycleEvents() throws {
      guard #available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *) else {
        return
      }

      let container = try ObservationSpikeModel.makeContainer(
        testName: "ObservationLifecycle"
      )
      let context = container.viewContext
      let item = try ObservationSpikeModel.makeItem(in: context)
      item.name = "initial"
      try context.save()

      let counter = ObservationChangeCounter()
      _ = withObservationTracking {
        item.name
      } onChange: {
        counter.increment()
      }

      context.refresh(item, mergeChanges: true)
      item.invalidate(\.name)
      #expect(counter.value == 1)

      item.name = "updated"
      try context.save()
      context.delete(item)
      item.invalidate(\.name)
      context.reset()
      item.invalidate(\.timestamp)
    }

    @MainActor
    @Test("T04 weak observation table can rekey temporary object IDs")
    func weakObservationTableRekeysTemporaryObjectIDs() throws {
      guard #available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *) else {
        return
      }

      let container = try ObservationSpikeModel.makeContainer(
        testName: "ObservationObjectIDRekey"
      )
      let context = container.viewContext
      let item = try ObservationSpikeModel.makeItem(in: context)
      let table = ObservationObjectIDTable<ObservationSpikeItem>()
      let temporaryID = item.objectID

      #expect(temporaryID.isTemporaryID)
      table.register(item)

      try context.obtainPermanentIDs(for: [item])
      table.rekey(item, from: temporaryID)

      #expect(table.contains(temporaryID) == false)
      #expect(item.objectID.isTemporaryID == false)
      #expect(table.contains(item.objectID))
    }

    @Test("T04 weak observation table releases unused objects")
    func weakObservationTableReleasesUnusedObjects() {
      guard #available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *) else {
        return
      }

      let table = WeakObservationTable<ObservationProbeObject>()
      weak var weakObject: ObservationProbeObject?

      do {
        let object = ObservationProbeObject()
        weakObject = object
        table.register(object)
        #expect(table.liveCount == 1)
      }

      #expect(weakObject == nil)
      #expect(table.liveCount == 0)
    }

    @MainActor
    @Test("T05 generated-style accessor mutation and primitive backstop")
    func generatedStyleAccessorMutationAndPrimitiveBackstop() throws {
      guard #available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *) else {
        return
      }

      let container = try ObservationSpikeModel.makeContainer(
        testName: "ObservationGeneratedStyleAccessor"
      )
      let context = container.viewContext
      let item = try ObservationSpikeModel.makeItem(in: context)
      item.name = "initial"

      let setterCounter = ObservationChangeCounter()
      _ = withObservationTracking {
        item.name
      } onChange: {
        setterCounter.increment()
      }

      item.name = "setter"
      #expect(setterCounter.value == 1)

      let primitiveCounter = ObservationChangeCounter()
      _ = withObservationTracking {
        item.name
      } onChange: {
        primitiveCounter.increment()
      }

      item.writeNameThroughPrimitiveStorage("primitive")
      #expect(primitiveCounter.value == 0)

      item.invalidate(\.name)
      #expect(primitiveCounter.value == 1)
      #expect(item.name == "primitive")
    }

    @MainActor
    @Test("T06 viewContext local changes expose keys until save")
    func viewContextLocalChangesExposeKeysUntilSave() throws {
      guard #available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *) else {
        return
      }

      let harness = try ObservationChangeModel.makeHarness(
        testName: "ObservationLocalChangeKeys"
      )
      let context = harness.context
      let parentID = harness.parent.objectID.cdeObservationTestID
      let recorder = CoreDataNotificationRecorder(
        context: context,
        names: [
          Notification.Name.NSManagedObjectContextObjectsDidChange,
          Notification.Name.NSManagedObjectContextWillSave,
        ]
      )

      harness.parent.setValue("renamed", forKey: "name")
      context.processPendingChanges()

      #expect(harness.parent.cdeObservationPendingKeys == ["name"])

      let objectSnapshots = recorder.snapshots(
        for: Notification.Name.NSManagedObjectContextObjectsDidChange
      )
      #expect(objectSnapshots.contains { $0.updatedObjectIDs.contains(parentID) })
      #expect(objectSnapshots.contains { $0.currentEventKeys(for: harness.parent) == ["name"] })

      try context.save()

      let willSaveSnapshots = recorder.snapshots(
        for: Notification.Name.NSManagedObjectContextWillSave
      )
      #expect(willSaveSnapshots.last?.updatedObjectIDs.contains(parentID) == true)
      #expect(willSaveSnapshots.last?.keys(for: harness.parent) == ["name"])
      #expect(harness.parent.cdeObservationPendingKeys.isEmpty)
      #expect(harness.parent.cdeObservationCurrentEventKeys.isEmpty)
    }

    @MainActor
    @Test("T06 KVC inverse and undo paths remain visible to Core Data change hooks")
    func bypassMutationPathsRemainVisibleToCoreDataChangeHooks() throws {
      guard #available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *) else {
        return
      }

      let harness = try ObservationChangeModel.makeHarness(
        testName: "ObservationLocalBypassPaths"
      )
      let context = harness.context
      context.undoManager = UndoManager()
      let recorder = CoreDataNotificationRecorder(
        context: context,
        names: [Notification.Name.NSManagedObjectContextObjectsDidChange]
      )

      harness.parent.setValue("kvc", forKey: "name")
      context.processPendingChanges()
      #expect(harness.parent.cdeObservationPendingKeys.contains("name"))

      harness.child.setValue(harness.parent, forKey: "parent")
      context.processPendingChanges()
      #expect(harness.child.cdeObservationPendingKeys.contains("parent"))
      #expect(harness.parent.cdeObservationPendingKeys.contains("children"))

      try context.save()
      recorder.reset()

      harness.parent.setValue("undoable", forKey: "name")
      context.processPendingChanges()
      context.undo()
      context.processPendingChanges()
      context.redo()
      context.processPendingChanges()

      let objectSnapshots = recorder.snapshots(
        for: Notification.Name.NSManagedObjectContextObjectsDidChange
      )
      #expect(
        objectSnapshots.contains { $0.currentEventKeys(for: harness.parent).contains("name") })
      #expect(harness.parent.cdeObservationPendingKeys.contains("name"))
    }

    @MainActor
    @Test("T07 changedValues covers property kinds needed by save hook")
    func changedValuesCoverageMatrix() throws {
      guard #available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *) else {
        return
      }

      let attribute = try ObservationChangeModel.makeHarness(
        testName: "ObservationChangedValuesAttribute"
      )
      attribute.parent.setValue("changed", forKey: "name")
      #expect(attribute.parent.cdeObservationPendingKeys == ["name"])
      try attribute.context.save()
      #expect(attribute.parent.cdeObservationPendingKeys.isEmpty)

      let toOne = try ObservationChangeModel.makeHarness(
        testName: "ObservationChangedValuesToOne"
      )
      toOne.child.setValue(toOne.parent, forKey: "parent")
      #expect(toOne.child.cdeObservationPendingKeys.contains("parent"))
      #expect(toOne.parent.cdeObservationPendingKeys.contains("children"))

      let unorderedToMany = try ObservationChangeModel.makeHarness(
        testName: "ObservationChangedValuesUnorderedToMany"
      )
      unorderedToMany.parent.mutableSetValue(forKey: "children").add(unorderedToMany.child)
      #expect(unorderedToMany.parent.cdeObservationPendingKeys.contains("children"))
      #expect(unorderedToMany.child.cdeObservationPendingKeys.contains("parent"))

      let orderedToMany = try ObservationChangeModel.makeHarness(
        testName: "ObservationChangedValuesOrderedToMany"
      )
      orderedToMany.parent.mutableOrderedSetValue(forKey: "orderedChildren").add(
        orderedToMany.orderedChild
      )
      #expect(orderedToMany.parent.cdeObservationPendingKeys.contains("orderedChildren"))
      #expect(orderedToMany.orderedChild.cdeObservationPendingKeys.contains("orderedParent"))

      let composition = try ObservationChangeModel.makeHarness(
        testName: "ObservationChangedValuesComposition"
      )
      composition.parent.setValue("{\"nickname\":\"A\"}", forKey: "profileStorage")
      #expect(composition.parent.cdeObservationPendingKeys == ["profileStorage"])

      let transient = try ObservationChangeModel.makeHarness(
        testName: "ObservationChangedValuesTransient"
      )
      transient.parent.setValue("draft", forKey: "transientNote")
      #expect(transient.parent.cdeObservationPendingKeys.isEmpty)
      #expect(transient.parent.cdeObservationCurrentEventKeys == ["transientNote"])

      let ignored = try ObservationChangeModel.makeHarness(
        testName: "ObservationChangedValuesIgnored"
      )
      ignored.parent.ignoredNote = "ignored"
      #expect(ignored.parent.cdeObservationPendingKeys.isEmpty)
      #expect(ignored.parent.cdeObservationCurrentEventKeys.isEmpty)
    }

    @Test("T08 field map fans out Core Data keys to observable field IDs")
    func fieldMapFansOutCoreDataKeysToObservableFieldIDs() {
      let children = ObservationFieldMap.mvp.fieldSet(for: ["children"])

      #expect(children == ObservationFieldSet([.children, .childrenCount]))
      #expect(children.swiftPaths == ["children", "childrenCount"])

      let orderedChildren = ObservationFieldMap.mvp.fieldSet(for: ["orderedChildren"])
      #expect(orderedChildren == ObservationFieldSet([.orderedChildren, .orderedChildrenCount]))

      let composition = ObservationFieldMap.mvp.fieldSet(for: ["profileStorage"])
      #expect(composition == ObservationFieldSet([.profile]))

      let combined = ObservationFieldMap.mvp.fieldSet(for: [
        "name",
        "children",
        "profileStorage",
        "unknown",
      ])
      #expect(combined == ObservationFieldSet([.name, .children, .childrenCount, .profile]))
      #expect(combined.swiftPaths == ["name", "children", "childrenCount", "profile"])
    }

    @Test("T08 field identity can use compact bitsets before keyPath dispatch")
    func fieldIdentityCanUseCompactBitsetsBeforeKeyPathDispatch() {
      let relationship = ObservationFieldSet([.children, .childrenCount])
      let scalar = ObservationFieldSet([.name])
      let combined = relationship.union(scalar)

      #expect(combined.contains(.name))
      #expect(combined.contains(.children))
      #expect(combined.contains(.childrenCount))
      #expect(combined.contains(.parent) == false)
      #expect(combined.count == 3)
      #expect(combined.rawBits == 0b1101)
    }

    @MainActor
    @Test("T13 merge notifications align background object IDs with pending keys")
    func mergeNotificationsAlignBackgroundObjectIDsWithPendingKeys() async throws {
      guard #available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *) else {
        return
      }

      let automatic = try ObservationChangeModel.makeHarness(
        testName: "ObservationMergeAutomatic",
        automaticallyMergesChangesFromParent: true
      )
      let automaticID = automatic.parent.objectID
      let automaticIDString = automaticID.cdeObservationTestID
      let automaticRecorder = CoreDataNotificationRecorder(
        context: automatic.context,
        names: [
          NSManagedObjectContext.didMergeChangesObjectIDsNotification,
          Notification.Name.NSManagedObjectContextObjectsDidChange,
        ]
      )
      let automaticBackground = automatic.container.newBackgroundContext()

      let automaticKeys = try await automaticBackground.perform {
        let backgroundParent = try automaticBackground.existingObject(with: automaticID)
        backgroundParent.setValue("background", forKey: "name")
        let keys = backgroundParent.cdeObservationPendingKeys
        try automaticBackground.save()
        return keys
      }

      #expect(automaticKeys == ["name"])

      let automaticMerge = await snapshot(
        from: automaticRecorder,
        name: NSManagedObjectContext.didMergeChangesObjectIDsNotification,
        containing: automaticIDString
      )
      #expect(automaticMerge?.updatedObjectIDs.contains(automaticIDString) == true)

      let automaticObjectChange = await snapshot(
        from: automaticRecorder,
        name: Notification.Name.NSManagedObjectContextObjectsDidChange,
        containing: automaticIDString
      )
      #expect(
        automaticObjectChange?.updatedObjectIDs.contains(automaticIDString) == true
          || automaticObjectChange?.refreshedObjectIDs.contains(automaticIDString) == true
      )

      let exactDecisions = ObservationInvalidationPlanner.decisions(
        affectedObjectIDs: automaticMerge?.updatedObjectIDs ?? [],
        pendingKeysByObjectID: [automaticIDString: automaticKeys]
      )
      #expect(exactDecisions[automaticIDString] == .exact(["name"]))

      let fallbackDecisions = ObservationInvalidationPlanner.decisions(
        affectedObjectIDs: automaticMerge?.updatedObjectIDs ?? [],
        pendingKeysByObjectID: [:]
      )
      #expect(fallbackDecisions[automaticIDString] == .allObservableKeyPaths)

      let manual = try ObservationChangeModel.makeHarness(
        testName: "ObservationMergeManual",
        automaticallyMergesChangesFromParent: false
      )
      let manualID = manual.parent.objectID
      let manualIDString = manualID.cdeObservationTestID
      let manualRecorder = CoreDataNotificationRecorder(
        context: manual.context,
        names: [NSManagedObjectContext.didMergeChangesObjectIDsNotification]
      )
      let manualBackground = manual.container.newBackgroundContext()
      let backgroundRecorder = CoreDataNotificationRecorder(
        context: manualBackground,
        names: [Notification.Name.NSManagedObjectContextDidSave]
      )

      let manualKeys = try await manualBackground.perform {
        let backgroundParent = try manualBackground.existingObject(with: manualID)
        backgroundParent.setValue("manual", forKey: "name")
        let keys = backgroundParent.cdeObservationPendingKeys
        try manualBackground.save()
        return keys
      }

      let saveNotification = try #require(
        backgroundRecorder.lastNotification(for: Notification.Name.NSManagedObjectContextDidSave)
      )
      manual.context.mergeChanges(fromContextDidSave: saveNotification)
      manual.context.processPendingChanges()

      #expect(manualKeys == ["name"])

      let manualMerge = await snapshot(
        from: manualRecorder,
        name: NSManagedObjectContext.didMergeChangesObjectIDsNotification,
        containing: manualIDString
      )
      #expect(manualMerge?.updatedObjectIDs.contains(manualIDString) == true)
    }

    @MainActor
    @Test("T14 batch operations provide object IDs and require all-key fallback")
    func batchOperationsProvideObjectIDsAndRequireAllKeyFallback() async throws {
      guard #available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *) else {
        return
      }

      let updateHarness = try ObservationChangeModel.makeHarness(
        testName: "ObservationBatchUpdate",
        automaticallyMergesChangesFromParent: false
      )
      let updateID = updateHarness.parent.objectID
      let updateIDString = updateID.cdeObservationTestID
      let updateRecorder = CoreDataNotificationRecorder(
        context: updateHarness.context,
        names: [NSManagedObjectContext.didMergeChangesObjectIDsNotification]
      )
      let updateBackground = updateHarness.container.newBackgroundContext()

      let updatedIDs = try await updateBackground.perform {
        let request = NSBatchUpdateRequest(entityName: ObservationChangeModel.parentEntityName)
        request.predicate = NSPredicate(format: "name == %@", "parent")
        request.propertiesToUpdate = ["name": "batch-updated"]
        request.resultType = .updatedObjectIDsResultType
        let result = try #require(
          updateBackground.execute(request) as? NSBatchUpdateResult
        )
        return try #require(result.result as? [NSManagedObjectID])
      }

      #expect(updatedIDs.map(\.cdeObservationTestID).contains(updateIDString))

      NSManagedObjectContext.mergeChanges(
        fromRemoteContextSave: [NSUpdatedObjectIDsKey: updatedIDs],
        into: [updateHarness.context]
      )

      let updateMerge = await snapshot(
        from: updateRecorder,
        name: NSManagedObjectContext.didMergeChangesObjectIDsNotification,
        containing: updateIDString
      )
      #expect(updateMerge?.updatedObjectIDs.contains(updateIDString) == true)

      let updateFallback = ObservationInvalidationPlanner.decisions(
        affectedObjectIDs: updateMerge?.updatedObjectIDs ?? [],
        pendingKeysByObjectID: [:]
      )
      #expect(updateFallback[updateIDString] == .allObservableKeyPaths)

      let statusOnlyResult = try await updateBackground.perform {
        let request = NSBatchUpdateRequest(entityName: ObservationChangeModel.parentEntityName)
        request.predicate = NSPredicate(format: "name == %@", "batch-updated")
        request.propertiesToUpdate = ["profileStorage": "status-only"]
        request.resultType = .statusOnlyResultType
        let result = try #require(
          updateBackground.execute(request) as? NSBatchUpdateResult
        )
        return try #require(result.result as? Bool)
      }
      #expect(statusOnlyResult)
      #expect(
        ObservationInvalidationPlanner.decisions(
          affectedObjectIDs: [],
          pendingKeysByObjectID: [:]
        ).isEmpty
      )

      let deleteHarness = try ObservationChangeModel.makeHarness(
        testName: "ObservationBatchDelete",
        automaticallyMergesChangesFromParent: false
      )
      let deleteID = deleteHarness.parent.objectID
      let deleteIDString = deleteID.cdeObservationTestID
      let deleteRecorder = CoreDataNotificationRecorder(
        context: deleteHarness.context,
        names: [NSManagedObjectContext.didMergeChangesObjectIDsNotification]
      )
      let deleteBackground = deleteHarness.container.newBackgroundContext()

      let deletedIDs = try await deleteBackground.perform {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(
          entityName: ObservationChangeModel.parentEntityName
        )
        fetchRequest.predicate = NSPredicate(format: "name == %@", "parent")
        let request = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        request.resultType = .resultTypeObjectIDs
        let result = try #require(
          deleteBackground.execute(request) as? NSBatchDeleteResult
        )
        return try #require(result.result as? [NSManagedObjectID])
      }

      #expect(deletedIDs.map(\.cdeObservationTestID).contains(deleteIDString))

      NSManagedObjectContext.mergeChanges(
        fromRemoteContextSave: [NSDeletedObjectIDsKey: deletedIDs],
        into: [deleteHarness.context]
      )

      let deleteMerge = await snapshot(
        from: deleteRecorder,
        name: NSManagedObjectContext.didMergeChangesObjectIDsNotification,
        containing: deleteIDString
      )
      #expect(deleteMerge?.deletedObjectIDs.contains(deleteIDString) == true)

      let deleteFallback = ObservationInvalidationPlanner.decisions(
        affectedObjectIDs: deleteMerge?.deletedObjectIDs ?? [],
        pendingKeysByObjectID: [:]
      )
      #expect(deleteFallback[deleteIDString] == .allObservableKeyPaths)
    }

    @MainActor
    @Test("T09 hub weak table filters registered but unobserved objects")
    func hubWeakTableFiltersRegisteredButUnobservedObjects() throws {
      guard #available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *) else {
        return
      }

      let harness = try ObservationChangeModel.makeHarness(
        testName: "ObservationHubRegisteredFilter"
      )
      let observedID = harness.parent.objectID
      let observedIDString = observedID.cdeObservationTestID
      let unobservedID = harness.secondParent.objectID
      let unobservedIDString = unobservedID.cdeObservationTestID
      let observedObjects = ObservationObjectIDTable<ObservationChangeParent>()
      let buffer = ObservationChangeBuffer()
      let token = ObservationSaveToken()

      observedObjects.register(harness.parent)
      buffer.register(token: token, objectID: observedIDString, keys: ["name"])
      buffer.register(token: token, objectID: unobservedIDString, keys: ["name"])

      #expect(harness.context.registeredObject(for: observedID) === harness.parent)
      #expect(harness.context.registeredObject(for: unobservedID) != nil)

      let plan = ObservationHubSelector.plan(
        affectedObjectIDs: [observedID, unobservedID],
        observedObjects: observedObjects,
        buffer: buffer
      )

      #expect(plan.lookupCount == 2)
      #expect(plan.invalidations[observedIDString] == .exact(["name"]))
      #expect(plan.invalidations[unobservedIDString] == nil)
      #expect(buffer.pendingObjectCount == 0)
      #expect(buffer.tokenCount == 0)
    }

    @MainActor
    @Test("T09 hub can notify an observed object that is currently a fault")
    func hubCanNotifyObservedFaultObject() throws {
      guard #available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *) else {
        return
      }

      let harness = try ObservationChangeModel.makeHarness(
        testName: "ObservationHubFaultObject"
      )
      let objectID = harness.parent.objectID
      let objectIDString = objectID.cdeObservationTestID
      let observedObjects = ObservationObjectIDTable<ObservationChangeParent>()
      let buffer = ObservationChangeBuffer()
      let token = ObservationSaveToken()

      observedObjects.register(harness.parent)
      buffer.register(token: token, objectID: objectIDString, keys: ["name"])
      harness.context.refresh(harness.parent, mergeChanges: false)

      #expect(harness.parent.isFault)
      #expect(harness.context.registeredObject(for: objectID) === harness.parent)

      let plan = ObservationHubSelector.plan(
        affectedObjectIDs: [objectID],
        observedObjects: observedObjects,
        buffer: buffer
      )

      #expect(plan.invalidations[objectIDString] == .exact(["name"]))
      #expect(plan.lookupCount == 1)
    }

    @MainActor
    @Test("T09 weak table cleanup removes deleted or reset objects")
    func weakTableCleanupRemovesDeletedOrResetObjects() throws {
      guard #available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *) else {
        return
      }

      let harness = try ObservationChangeModel.makeHarness(
        testName: "ObservationHubCleanup"
      )
      let deletedID = harness.parent.objectID
      let deletedIDString = deletedID.cdeObservationTestID
      let resetID = harness.secondParent.objectID
      let observedObjects = ObservationObjectIDTable<ObservationChangeParent>()
      let buffer = ObservationChangeBuffer()
      let token = ObservationSaveToken()

      observedObjects.register(harness.parent)
      observedObjects.register(harness.secondParent)
      harness.context.delete(harness.parent)
      observedObjects.unregister(deletedID)
      buffer.register(token: token, objectID: deletedIDString, keys: ["name"])

      let deletePlan = ObservationHubSelector.plan(
        affectedObjectIDs: [deletedID],
        observedObjects: observedObjects,
        buffer: buffer
      )

      #expect(deletePlan.invalidations[deletedIDString] == nil)
      #expect(buffer.pendingObjectCount == 0)

      harness.context.reset()
      observedObjects.removeAll()

      #expect(observedObjects.liveObjectIDs.isEmpty)
      #expect(harness.context.registeredObject(for: resetID) == nil)
    }

    @MainActor
    @Test("T09 weak table prunes released observed objects")
    func weakTablePrunesReleasedObservedObjects() throws {
      guard #available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *) else {
        return
      }

      let container = try ObservationChangeModel.makeContainer(
        testName: "ObservationHubReleasedObject"
      )
      let context = container.viewContext
      let observedObjects = ObservationObjectIDTable<ObservationChangeParent>()
      weak var weakParent: ObservationChangeParent?
      var parentID: NSManagedObjectID?

      try autoreleasepool {
        let parent = try ObservationChangeModel.makeParent(in: context, name: "released")
        try context.save()
        parentID = parent.objectID
        weakParent = parent
        observedObjects.register(parent)
        #expect(observedObjects.contains(parent.objectID))
      }

      context.reset()

      #expect(weakParent == nil)
      #expect(observedObjects.liveObjectIDs.isEmpty)
      if let parentID {
        #expect(context.registeredObject(for: parentID) == nil)
      }
    }

    @MainActor
    @Test("T09 hub lookup is bounded by merge object IDs")
    func hubLookupIsBoundedByMergeObjectIDs() throws {
      guard #available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *) else {
        return
      }

      let harness = try ObservationChangeModel.makeHarness(
        testName: "ObservationHubLookupCost"
      )
      let objectID = harness.parent.objectID
      let objectIDString = objectID.cdeObservationTestID
      let observedObjects = ObservationObjectIDTable<ObservationChangeParent>()
      let buffer = ObservationChangeBuffer()
      let activeToken = ObservationSaveToken()

      observedObjects.register(harness.parent)
      buffer.register(token: activeToken, objectID: objectIDString, keys: ["name"])

      for index in 0..<25 {
        buffer.register(
          token: ObservationSaveToken(),
          objectID: "object://historical-\(index)",
          keys: ["name"]
        )
      }

      let plan = ObservationHubSelector.plan(
        affectedObjectIDs: [objectID],
        observedObjects: observedObjects,
        buffer: buffer
      )

      #expect(plan.lookupCount == 1)
      #expect(plan.invalidations[objectIDString] == .exact(["name"]))
      #expect(buffer.pendingObjectCount == 25)
      #expect(buffer.pendingChange(for: "object://historical-0") == .keyPaths(["name"]))
    }

    @Test("T15 to-one relationship tracking composes by instance")
    func toOneRelationshipTrackingComposesByInstance() {
      guard #available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *) else {
        return
      }

      let root = ObservationRelationshipProbeObject(name: "root")
      let middle = ObservationRelationshipProbeObject(name: "middle")
      let leaf = ObservationRelationshipProbeObject(name: "leaf")
      root.child = middle
      middle.child = leaf

      let bindingCounter = ObservationChangeCounter()
      _ = withObservationTracking {
        root.child?.name
      } onChange: {
        bindingCounter.increment()
      }

      leaf.name = "leaf-renamed"
      #expect(bindingCounter.value == 0)

      root.child = ObservationRelationshipProbeObject(name: "replacement")
      #expect(bindingCounter.value == 1)

      let deepCounter = ObservationChangeCounter()
      _ = withObservationTracking {
        root.child?.child?.name
      } onChange: {
        deepCounter.increment()
      }

      root.child?.child = leaf
      #expect(deepCounter.value == 1)

      let leafCounter = ObservationChangeCounter()
      _ = withObservationTracking {
        root.child?.child?.name
      } onChange: {
        leafCounter.increment()
      }

      leaf.name = "leaf-read-again"
      #expect(leafCounter.value == 1)
    }

    @Test("T15 to-many helper must fan out relationship and count")
    func toManyHelperMustFanOutRelationshipAndCount() {
      guard #available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *) else {
        return
      }

      let parent = ObservationRelationshipProbeObject(name: "parent")
      let storageOnlyChild = ObservationRelationshipProbeObject(name: "storage")
      let helperChild = ObservationRelationshipProbeObject(name: "helper")
      let countCounter = ObservationChangeCounter()

      _ = withObservationTracking {
        parent.childrenCount
      } onChange: {
        countCounter.increment()
      }

      parent.addChildThroughStorageOnly(storageOnlyChild)
      #expect(countCounter.value == 0)

      parent.addChildWithGeneratedHelper(helperChild)
      #expect(countCounter.value == 1)
      #expect(parent.childrenCount == 2)

      let childrenCounter = ObservationChangeCounter()
      _ = withObservationTracking {
        parent.children.map(\.name)
      } onChange: {
        childrenCounter.increment()
      }

      parent.addChildWithGeneratedHelper(ObservationRelationshipProbeObject(name: "next"))
      #expect(childrenCounter.value == 1)
    }

    @MainActor
    @Test("T15 inverse relationship changes carry owner membership keys")
    func inverseRelationshipChangesCarryOwnerMembershipKeys() throws {
      guard #available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *) else {
        return
      }

      let harness = try ObservationChangeModel.makeHarness(
        testName: "ObservationRelationshipInverseMove"
      )

      harness.child.setValue(harness.parent, forKey: "parent")
      try harness.context.save()

      harness.child.setValue(harness.secondParent, forKey: "parent")
      harness.context.processPendingChanges()

      #expect(harness.child.cdeObservationPendingKeys.contains("parent"))
      #expect(harness.parent.cdeObservationPendingKeys.contains("children"))
      #expect(harness.secondParent.cdeObservationPendingKeys.contains("children"))
      #expect(
        ObservationSaveHookKeyMap.mvp.observableKeyPaths(for: ["children"])
          == ["children", "childrenCount"]
      )
    }

    @MainActor
    @Test("T15 ordered to-many relationship keys fan out to derived count")
    func orderedToManyRelationshipKeysFanOutToDerivedCount() throws {
      guard #available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *) else {
        return
      }

      let harness = try ObservationChangeModel.makeHarness(
        testName: "ObservationOrderedRelationshipFanOut"
      )

      harness.parent.mutableOrderedSetValue(forKey: "orderedChildren").add(
        harness.orderedChild
      )

      #expect(harness.parent.cdeObservationPendingKeys.contains("orderedChildren"))
      #expect(harness.orderedChild.cdeObservationPendingKeys.contains("orderedParent"))
      #expect(
        ObservationSaveHookKeyMap.mvp.observableKeyPaths(for: ["orderedChildren"])
          == ["orderedChildren", "orderedChildrenCount"]
      )
    }

    @Test("T16 composition top-level invalidation matches current read path")
    func compositionTopLevelInvalidationMatchesCurrentReadPath() {
      guard #available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *) else {
        return
      }

      let probe = ObservationCompositionProbe(
        profile: .init(nickname: "fat", score: 1)
      )
      let profileCounter = ObservationChangeCounter()

      _ = withObservationTracking {
        probe.profile.nickname
      } onChange: {
        profileCounter.increment()
      }

      probe.invalidate(\.nicknameLeaf)
      #expect(profileCounter.value == 0)

      probe.invalidate(\.profile)
      #expect(profileCounter.value == 1)

      let leafCounter = ObservationChangeCounter()
      _ = withObservationTracking {
        probe.nicknameLeaf
      } onChange: {
        leafCounter.increment()
      }

      probe.invalidate(\.profile)
      #expect(leafCounter.value == 0)

      probe.invalidate(\.nicknameLeaf)
      #expect(leafCounter.value == 1)
    }

    @MainActor
    @Test("T16 composition transient and ignored save-hook granularity")
    func compositionTransientAndIgnoredSaveHookGranularity() throws {
      guard #available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *) else {
        return
      }

      let harness = try ObservationChangeModel.makeHarness(
        testName: "ObservationCompositionGranularity"
      )

      harness.parent.setValue("{\"nickname\":\"A\"}", forKey: "profileStorage")
      #expect(harness.parent.cdeObservationPendingKeys == ["profileStorage"])
      #expect(
        ObservationSaveHookKeyMap.mvp.observableKeyPaths(for: ["profileStorage"]) == ["profile"]
      )
      #expect(ObservationSaveHookKeyMap.mvp.observableKeyPaths(for: ["nickname"]).isEmpty)

      harness.parent.setValue("draft", forKey: "transientNote")
      #expect(harness.parent.cdeObservationCurrentEventKeys.contains("transientNote"))
      #expect(harness.parent.cdeObservationPendingKeys == ["profileStorage"])
      #expect(ObservationSaveHookKeyMap.mvp.observableKeyPaths(for: ["transientNote"]).isEmpty)

      harness.parent.ignoredNote = "ignored"
      #expect(harness.parent.cdeObservationPendingKeys == ["profileStorage"])
      #expect(harness.parent.cdeObservationCurrentEventKeys.contains("ignoredNote") == false)
    }

    @MainActor
    @Test("T17 save-driven insert needs weak table rekey")
    func saveDrivenInsertNeedsWeakTableRekey() throws {
      guard #available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *) else {
        return
      }

      let container = try ObservationChangeModel.makeContainer(
        testName: "ObservationInsertedObjectRekey"
      )
      let context = container.viewContext
      let parent = try ObservationChangeModel.makeParent(in: context, name: "inserted")
      let observedObjects = ObservationObjectIDTable<ObservationChangeParent>()
      let temporaryID = parent.objectID

      #expect(temporaryID.isTemporaryID)

      observedObjects.register(parent)
      try context.save()

      let permanentID = parent.objectID

      #expect(permanentID.isTemporaryID == false)
      #expect(observedObjects.contains(permanentID) == false)

      observedObjects.rekey(parent, from: temporaryID)

      #expect(observedObjects.contains(temporaryID) == false)
      #expect(observedObjects.contains(permanentID))
    }

    @MainActor
    @Test("T17 inserted child updates existing owner membership metadata")
    func insertedChildUpdatesExistingOwnerMembershipMetadata() async throws {
      guard #available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *) else {
        return
      }

      let harness = try ObservationChangeModel.makeHarness(
        testName: "ObservationInsertedChildOwner",
        automaticallyMergesChangesFromParent: true
      )
      let parentID = harness.parent.objectID
      let parentIDString = parentID.cdeObservationTestID
      let actor = ObservationMetadataActor(container: harness.container)
      let buffer = ObservationChangeBuffer()
      let recorder = CoreDataNotificationRecorder(
        context: harness.context,
        names: [NSManagedObjectContext.didMergeChangesObjectIDsNotification]
      )

      let childID = try await actor.insertChildAttachedToParentWithObservedSave(
        parentID: parentID,
        childName: "inserted-child",
        buffer: buffer
      )
      let childIDString = childID.cdeObservationTestID

      #expect(childID.isTemporaryID == false)
      #expect(buffer.pendingChange(for: parentIDString) == .keyPaths(["children"]))
      #expect(buffer.pendingChange(for: childIDString) == nil)
      #expect(
        ObservationSaveHookKeyMap.mvp.observableKeyPaths(for: ["children"])
          == ["children", "childrenCount"]
      )

      let merge = await snapshot(
        from: recorder,
        name: NSManagedObjectContext.didMergeChangesObjectIDsNotification,
        containing: parentIDString
      )

      #expect(merge?.updatedObjectIDs.contains(parentIDString) == true)
      #expect(merge?.insertedObjectIDs.contains(childIDString) == true)
      #expect(buffer.consume(objectID: parentIDString) == .keyPaths(["children"]))
      #expect(buffer.pendingObjectCount == 0)
      #expect(buffer.tokenCount == 0)
    }

    @MainActor
    @Test("T10 NSModelActor save wrapper produces metadata and defines bypass fallback")
    func nsModelActorSaveWrapperProducesMetadataAndDefinesBypassFallback() async throws {
      guard #available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *) else {
        return
      }

      let harness = try ObservationChangeModel.makeHarness(
        testName: "ObservationModelActorSaveWrapper",
        automaticallyMergesChangesFromParent: true
      )
      let parentID = harness.parent.objectID
      let parentIDString = parentID.cdeObservationTestID
      let actor = ObservationMetadataActor(container: harness.container)
      let buffer = ObservationChangeBuffer()
      let eventLog = ObservationEventLog()
      let mergeEventRecorder = ObservationNotificationEventRecorder(
        context: harness.context,
        name: NSManagedObjectContext.didMergeChangesObjectIDsNotification,
        eventLog: eventLog,
        event: "merge"
      )
      let recorder = CoreDataNotificationRecorder(
        context: harness.context,
        names: [NSManagedObjectContext.didMergeChangesObjectIDsNotification]
      )

      _ = try await actor.updateParentNameWithObservedSave(
        id: parentID,
        newName: "actor-observed",
        buffer: buffer,
        eventLog: eventLog
      )

      let observedMerge = await snapshot(
        from: recorder,
        name: NSManagedObjectContext.didMergeChangesObjectIDsNotification,
        containing: parentIDString
      )
      #expect(observedMerge?.updatedObjectIDs.contains(parentIDString) == true)
      #expect(buffer.pendingChange(for: parentIDString) == .keyPaths(["name"]))
      #expect(eventLog.firstIndex(of: "metadata") != nil)
      #expect(eventLog.firstIndex(of: "merge") != nil)
      #expect(
        (eventLog.firstIndex(of: "metadata") ?? Int.max)
          < (eventLog.firstIndex(of: "merge") ?? -1)
      )

      #expect(buffer.consume(objectID: parentIDString) == .keyPaths(["name"]))
      #expect(buffer.pendingObjectCount == 0)
      #expect(buffer.tokenCount == 0)

      do {
        try await actor.updateParentNameWithFailingObservedSave(
          id: parentID,
          buffer: buffer
        )
        Issue.record("Expected save failure for nil non-optional name.")
      } catch {
        #expect(buffer.pendingChange(for: parentIDString) == nil)
        #expect(buffer.pendingObjectCount == 0)
        #expect(buffer.tokenCount == 0)
      }

      let insertedID = try await actor.insertParentWithObservedSave(
        name: "inserted",
        buffer: buffer
      )
      #expect(buffer.pendingChange(for: insertedID.cdeObservationTestID) == nil)

      recorder.reset()
      try await actor.updateParentNameWithDirectSave(
        id: parentID,
        newName: "direct-save"
      )

      let directMerge = await snapshot(
        from: recorder,
        name: NSManagedObjectContext.didMergeChangesObjectIDsNotification,
        containing: parentIDString
      )
      let directDecision = ObservationInvalidationPlanner.decisions(
        affectedObjectIDs: directMerge?.updatedObjectIDs ?? [],
        pendingKeysByObjectID: [:]
      )
      #expect(directMerge?.updatedObjectIDs.contains(parentIDString) == true)
      #expect(directDecision[parentIDString] == .allObservableKeyPaths)
      #expect(mergeEventRecorder.isObserving)
    }

    @MainActor
    @Test("T21 registered ordinary context direct save stays precise before automatic merge")
    func registeredOrdinaryContextDirectSaveStaysPreciseBeforeAutomaticMerge() async throws {
      guard #available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *) else {
        return
      }

      let harness = try ObservationChangeModel.makeHarness(
        testName: "ObservationRegisteredContextAutomatic",
        automaticallyMergesChangesFromParent: true
      )
      let parentID = harness.parent.objectID
      let parentIDString = parentID.cdeObservationTestID
      let domain = ObservationRegisteredContextDomain()
      let eventLog = ObservationEventLog()
      let background = harness.container.newBackgroundContext()
      let producer = ObservationRegisteredContextProducer(
        context: background,
        domain: domain,
        eventLog: eventLog
      )
      let mergeEventRecorder = ObservationNotificationEventRecorder(
        context: harness.context,
        name: NSManagedObjectContext.didMergeChangesObjectIDsNotification,
        eventLog: eventLog,
        event: "merge"
      )
      let recorder = CoreDataNotificationRecorder(
        context: harness.context,
        names: [NSManagedObjectContext.didMergeChangesObjectIDsNotification]
      )

      try await background.perform {
        let backgroundParent = try background.existingObject(with: parentID)
        backgroundParent.setValue("ordinary-registered", forKey: "name")
        try background.save()
      }

      let merge = await snapshot(
        from: recorder,
        name: NSManagedObjectContext.didMergeChangesObjectIDsNotification,
        containing: parentIDString
      )
      let decisions = ObservationInvalidationPlanner.decisions(
        affectedObjectIDs: merge?.updatedObjectIDs ?? [],
        pendingKeysByObjectID: domain.pendingKeysSnapshot()
      )

      #expect(merge?.updatedObjectIDs.contains(parentIDString) == true)
      #expect(domain.pendingChange(for: parentIDString) == .keyPaths(["name"]))
      #expect(decisions[parentIDString] == .exact(["name"]))
      #expect(eventLog.firstIndex(of: "metadata") != nil)
      #expect(eventLog.firstIndex(of: "merge") != nil)
      #expect(
        (eventLog.firstIndex(of: "metadata") ?? Int.max)
          < (eventLog.firstIndex(of: "merge") ?? -1)
      )
      #expect(domain.consume(objectID: parentIDString) == .keyPaths(["name"]))
      #expect(producer.isObserving)
      #expect(mergeEventRecorder.isObserving)
    }

    @MainActor
    @Test("T21 unregistered ordinary context direct save falls back to all-key")
    func unregisteredOrdinaryContextDirectSaveFallsBackToAllKey() async throws {
      guard #available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *) else {
        return
      }

      let harness = try ObservationChangeModel.makeHarness(
        testName: "ObservationUnregisteredContextFallback",
        automaticallyMergesChangesFromParent: true
      )
      let parentID = harness.parent.objectID
      let parentIDString = parentID.cdeObservationTestID
      let domain = ObservationRegisteredContextDomain()
      let background = harness.container.newBackgroundContext()
      let recorder = CoreDataNotificationRecorder(
        context: harness.context,
        names: [NSManagedObjectContext.didMergeChangesObjectIDsNotification]
      )

      try await background.perform {
        let backgroundParent = try background.existingObject(with: parentID)
        backgroundParent.setValue("ordinary-unregistered", forKey: "name")
        try background.save()
      }

      let merge = await snapshot(
        from: recorder,
        name: NSManagedObjectContext.didMergeChangesObjectIDsNotification,
        containing: parentIDString
      )
      let decisions = ObservationInvalidationPlanner.decisions(
        affectedObjectIDs: merge?.updatedObjectIDs ?? [],
        pendingKeysByObjectID: domain.pendingKeysSnapshot()
      )

      #expect(merge?.updatedObjectIDs.contains(parentIDString) == true)
      #expect(domain.pendingChange(for: parentIDString) == nil)
      #expect(decisions[parentIDString] == .allObservableKeyPaths)
      #expect(domain.pendingObjectCount == 0)
    }

    @MainActor
    @Test("T21 registered ordinary context supports manual merge consumption")
    func registeredOrdinaryContextSupportsManualMergeConsumption() async throws {
      guard #available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *) else {
        return
      }

      let harness = try ObservationChangeModel.makeHarness(
        testName: "ObservationRegisteredContextManual",
        automaticallyMergesChangesFromParent: false
      )
      let parentID = harness.parent.objectID
      let parentIDString = parentID.cdeObservationTestID
      let domain = ObservationRegisteredContextDomain()
      let background = harness.container.newBackgroundContext()
      let producer = ObservationRegisteredContextProducer(
        context: background,
        domain: domain
      )
      let backgroundRecorder = CoreDataNotificationRecorder(
        context: background,
        names: [Notification.Name.NSManagedObjectContextDidSave]
      )
      let mergeRecorder = CoreDataNotificationRecorder(
        context: harness.context,
        names: [NSManagedObjectContext.didMergeChangesObjectIDsNotification]
      )

      try await background.perform {
        let backgroundParent = try background.existingObject(with: parentID)
        backgroundParent.setValue("ordinary-manual", forKey: "name")
        try background.save()
      }

      let saveNotification = try #require(
        backgroundRecorder.lastNotification(for: Notification.Name.NSManagedObjectContextDidSave)
      )
      harness.context.mergeChanges(fromContextDidSave: saveNotification)
      harness.context.processPendingChanges()

      let merge = await snapshot(
        from: mergeRecorder,
        name: NSManagedObjectContext.didMergeChangesObjectIDsNotification,
        containing: parentIDString
      )
      let decisions = ObservationInvalidationPlanner.decisions(
        affectedObjectIDs: merge?.updatedObjectIDs ?? [],
        pendingKeysByObjectID: domain.pendingKeysSnapshot()
      )

      #expect(merge?.updatedObjectIDs.contains(parentIDString) == true)
      #expect(domain.pendingChange(for: parentIDString) == .keyPaths(["name"]))
      #expect(decisions[parentIDString] == .exact(["name"]))
      #expect(domain.consume(objectID: parentIDString) == .keyPaths(["name"]))
      #expect(producer.isObserving)
    }

    @MainActor
    @Test("T21 registered ordinary contexts keep producer and container scope")
    func registeredOrdinaryContextsKeepProducerAndContainerScope() async throws {
      guard #available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *) else {
        return
      }

      let first = try ObservationChangeModel.makeHarness(
        testName: "ObservationRegisteredContextScopeFirst",
        automaticallyMergesChangesFromParent: false
      )
      let firstDomain = ObservationRegisteredContextDomain()
      let firstBackgroundA = first.container.newBackgroundContext()
      let firstBackgroundB = first.container.newBackgroundContext()
      let firstProducerA = ObservationRegisteredContextProducer(
        context: firstBackgroundA,
        domain: firstDomain
      )
      let firstProducerB = ObservationRegisteredContextProducer(
        context: firstBackgroundB,
        domain: firstDomain
      )
      let firstID = first.parent.objectID
      let firstIDString = firstID.cdeObservationTestID
      let secondID = first.secondParent.objectID
      let secondIDString = secondID.cdeObservationTestID

      try await firstBackgroundA.perform {
        let parent = try firstBackgroundA.existingObject(with: firstID)
        parent.setValue("scope-a", forKey: "name")
        try firstBackgroundA.save()
      }
      try await firstBackgroundB.perform {
        let parent = try firstBackgroundB.existingObject(with: secondID)
        parent.setValue("scope-b", forKey: "name")
        try firstBackgroundB.save()
      }

      #expect(firstDomain.pendingChange(for: firstIDString) == .keyPaths(["name"]))
      #expect(firstDomain.pendingChange(for: secondIDString) == .keyPaths(["name"]))
      #expect(firstDomain.pendingObjectCount == 2)
      #expect(firstDomain.tokenCount == 2)

      firstProducerA.invalidate()

      #expect(firstDomain.pendingChange(for: firstIDString) == nil)
      #expect(firstDomain.pendingChange(for: secondIDString) == .keyPaths(["name"]))
      #expect(firstDomain.pendingObjectCount == 1)
      #expect(firstDomain.tokenCount == 1)
      #expect(firstProducerB.isObserving)

      let other = try ObservationChangeModel.makeHarness(
        testName: "ObservationRegisteredContextScopeOtherContainer",
        automaticallyMergesChangesFromParent: false
      )
      let otherDomain = ObservationRegisteredContextDomain()
      let otherBackground = other.container.newBackgroundContext()
      let otherProducer = ObservationRegisteredContextProducer(
        context: otherBackground,
        domain: otherDomain
      )
      let otherID = other.parent.objectID
      let otherIDString = otherID.cdeObservationTestID

      try await otherBackground.perform {
        let parent = try otherBackground.existingObject(with: otherID)
        parent.setValue("scope-other", forKey: "name")
        try otherBackground.save()
      }

      #expect(firstDomain.pendingChange(for: otherIDString) == nil)
      #expect(otherDomain.pendingChange(for: otherIDString) == .keyPaths(["name"]))
      #expect(otherProducer.isObserving)
    }

    @MainActor
    @Test("T21 registered ordinary context cleans failure reset and invalidation state")
    func registeredOrdinaryContextCleansFailureResetAndInvalidationState() async throws {
      guard #available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *) else {
        return
      }

      let harness = try ObservationChangeModel.makeHarness(
        testName: "ObservationRegisteredContextCleanup",
        automaticallyMergesChangesFromParent: false
      )
      let parentID = harness.parent.objectID
      let parentIDString = parentID.cdeObservationTestID
      let secondID = harness.secondParent.objectID
      let secondIDString = secondID.cdeObservationTestID
      let domain = ObservationRegisteredContextDomain()
      let background = harness.container.newBackgroundContext()
      var producer: ObservationRegisteredContextProducer? = ObservationRegisteredContextProducer(
        context: background,
        domain: domain
      )

      try await background.perform {
        let parent = try background.existingObject(with: parentID)
        parent.setValue("cleanup-success", forKey: "name")
        try background.save()
      }

      #expect(domain.pendingChange(for: parentIDString) == .keyPaths(["name"]))
      #expect(domain.pendingObjectCount == 1)
      #expect(domain.tokenCount == 1)

      await background.perform {
        do {
          let parent = try background.existingObject(with: secondID)
          parent.setValue(nil, forKey: "name")
          try background.save()
          Issue.record("Expected save failure for nil non-optional name.")
        } catch {
          background.rollback()
        }
      }

      #expect(domain.pendingChange(for: parentIDString) == .keyPaths(["name"]))
      #expect(domain.pendingChange(for: secondIDString) == nil)
      #expect(domain.pendingObjectCount == 1)
      #expect(domain.tokenCount == 1)
      #expect(domain.stagedSaveCount == 0)

      await background.perform {
        background.reset()
      }

      #expect(domain.pendingObjectCount == 0)
      #expect(domain.tokenCount == 0)

      try await background.perform {
        let parent = try background.existingObject(with: parentID)
        parent.setValue("cleanup-invalidate", forKey: "name")
        try background.save()
      }

      #expect(domain.pendingChange(for: parentIDString) == .keyPaths(["name"]))

      producer = nil

      #expect(domain.pendingObjectCount == 0)
      #expect(domain.tokenCount == 0)
      #expect(producer == nil)
    }

    @MainActor
    @Test("T22 getter access registers observed object through active domain")
    func getterAccessRegistersObservedObjectThroughActiveDomain() throws {
      guard #available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *) else {
        return
      }

      let container = try ObservationSpikeModel.makeContainer(
        testName: "ObservationDomainGetterAssociation"
      )
      let context = container.viewContext
      let item = try ObservationSpikeModel.makeDomainItem(in: context)
      item.name = "initial"
      try context.save()

      let domain = CDEObservationDomainSkeleton(container: container)
      let counter = ObservationChangeCounter()

      #expect(CDEObservationDomainRegistry.domain(for: context) === domain)
      #expect(domain.liveObservedObjectIDs.isEmpty)

      _ = withObservationTracking {
        item.name
      } onChange: {
        counter.increment()
      }

      #expect(domain.containsObservedObject(item.objectID))
      #expect(domain.liveObservedObjectIDs == [item.objectID])

      item.name = "unsaved"
      #expect(counter.value == 0)

      item.invalidateName()
      #expect(counter.value == 1)
    }

    @MainActor
    @Test("T22 getter access without retained domain does not register routing")
    func getterAccessWithoutRetainedDomainDoesNotRegisterRouting() throws {
      guard #available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *) else {
        return
      }

      let container = try ObservationSpikeModel.makeContainer(
        testName: "ObservationDomainNoRetainedDomain"
      )
      let context = container.viewContext
      let item = try ObservationSpikeModel.makeDomainItem(in: context)
      item.name = "initial"
      try context.save()

      let counter = ObservationChangeCounter()

      #expect(CDEObservationDomainRegistry.domain(for: context) == nil)

      _ = withObservationTracking {
        item.name
      } onChange: {
        counter.increment()
      }

      #expect(CDEObservationDomainRegistry.domain(for: context) == nil)

      item.invalidateName()
      #expect(counter.value == 1)
    }

    @MainActor
    @Test("T22 domain invalidation and deinit remove viewContext association")
    func domainInvalidationAndDeinitRemoveViewContextAssociation() throws {
      guard #available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *) else {
        return
      }

      let container = try ObservationSpikeModel.makeContainer(
        testName: "ObservationDomainInvalidation"
      )
      let context = container.viewContext
      let item = try ObservationSpikeModel.makeDomainItem(in: context)
      item.name = "initial"
      try context.save()

      var domain: CDEObservationDomainSkeleton? = CDEObservationDomainSkeleton(
        container: container
      )
      weak var weakDomain: CDEObservationDomainSkeleton?
      weakDomain = domain

      _ = item.name
      #expect(domain?.containsObservedObject(item.objectID) == true)

      domain?.invalidate()

      #expect(CDEObservationDomainRegistry.domain(for: context) == nil)
      #expect(domain?.liveObservedObjectIDs.isEmpty == true)

      _ = item.name
      #expect(domain?.liveObservedObjectIDs.isEmpty == true)

      domain = nil
      #expect(weakDomain == nil)
    }

    @MainActor
    @Test("T22 domain owns registered producer lifecycle")
    func domainOwnsRegisteredProducerLifecycle() async throws {
      guard #available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *) else {
        return
      }

      let harness = try ObservationChangeModel.makeHarness(
        testName: "ObservationDomainProducerLifecycle",
        automaticallyMergesChangesFromParent: false
      )
      let domain = CDEObservationDomainSkeleton(container: harness.container)
      let background = harness.container.newBackgroundContext()
      let producer = domain.registerChangeProducer(context: background)
      let parentID = harness.parent.objectID
      let parentIDString = parentID.cdeObservationTestID

      try await background.perform {
        let parent = try background.existingObject(with: parentID)
        parent.setValue("domain-owned", forKey: "name")
        try background.save()
      }

      #expect(producer.isObserving)
      #expect(domain.pendingChange(for: parentIDString) == .keyPaths(["name"]))
      #expect(domain.pendingObjectCount == 1)

      domain.invalidate()

      #expect(producer.isObserving == false)
      #expect(domain.pendingChange(for: parentIDString) == nil)
      #expect(domain.pendingObjectCount == 0)
      #expect(CDEObservationDomainRegistry.domain(for: harness.context) == nil)
    }

    @MainActor
    @Test("T22 multiple domains keep getter associations isolated")
    func multipleDomainsKeepGetterAssociationsIsolated() throws {
      guard #available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *) else {
        return
      }

      let firstContainer = try ObservationSpikeModel.makeContainer(
        testName: "ObservationDomainIsolationFirst"
      )
      let secondContainer = try ObservationSpikeModel.makeContainer(
        testName: "ObservationDomainIsolationSecond"
      )
      let firstContext = firstContainer.viewContext
      let secondContext = secondContainer.viewContext
      let firstItem = try ObservationSpikeModel.makeDomainItem(in: firstContext)
      let secondItem = try ObservationSpikeModel.makeDomainItem(in: secondContext)
      firstItem.name = "first"
      secondItem.name = "second"
      try firstContext.save()
      try secondContext.save()

      let firstDomain = CDEObservationDomainSkeleton(container: firstContainer)
      let secondDomain = CDEObservationDomainSkeleton(container: secondContainer)

      _ = firstItem.name

      #expect(firstDomain.containsObservedObject(firstItem.objectID))
      #expect(firstDomain.containsObservedObject(secondItem.objectID) == false)
      #expect(secondDomain.liveObservedObjectIDs.isEmpty)

      _ = secondItem.name

      #expect(secondDomain.containsObservedObject(secondItem.objectID))
      #expect(secondDomain.containsObservedObject(firstItem.objectID) == false)
      #expect(firstDomain.liveObservedObjectIDs == [firstItem.objectID])
      #expect(secondDomain.liveObservedObjectIDs == [secondItem.objectID])
    }

    @MainActor
    @Test("T12 pending buffer merges consumes rolls back scopes and compresses")
    func pendingBufferMergesConsumesRollsBackScopesAndCompresses() {
      guard #available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *) else {
        return
      }

      let objectID = "object://one"
      let firstToken = ObservationSaveToken()
      let secondToken = ObservationSaveToken()
      let buffer = ObservationChangeBuffer()

      buffer.register(token: firstToken, objectID: objectID, keys: ["name"])
      buffer.register(token: secondToken, objectID: objectID, keys: ["profileStorage"])

      #expect(buffer.pendingChange(for: objectID) == .keyPaths(["name", "profileStorage"]))
      #expect(buffer.pendingObjectCount == 1)
      #expect(buffer.tokenCount == 2)

      buffer.rollback(token: secondToken)

      #expect(buffer.pendingChange(for: objectID) == .keyPaths(["name"]))
      #expect(buffer.tokenCount == 1)
      #expect(buffer.consume(objectID: objectID) == .keyPaths(["name"]))
      #expect(buffer.pendingObjectCount == 0)
      #expect(buffer.tokenCount == 0)

      let failedToken = ObservationSaveToken()
      buffer.register(token: failedToken, objectID: "object://failed", keys: ["name"])
      buffer.rollback(token: failedToken)
      #expect(buffer.pendingChange(for: "object://failed") == nil)

      let scopedA = ObservationChangeBuffer()
      let scopedB = ObservationChangeBuffer()
      let scopedToken = ObservationSaveToken()
      scopedA.register(token: scopedToken, objectID: objectID, keys: ["name"])
      #expect(scopedA.pendingChange(for: objectID) == .keyPaths(["name"]))
      #expect(scopedB.pendingChange(for: objectID) == nil)

      let staleObjectID = "object://stale"
      let staleToken = ObservationSaveToken()
      buffer.register(token: staleToken, objectID: staleObjectID, keys: ["name"])
      buffer.compress(objectID: staleObjectID)
      #expect(buffer.pendingChange(for: staleObjectID) == .allObservableKeyPaths)
      #expect(buffer.consume(objectID: staleObjectID) == .allObservableKeyPaths)
    }

    @MainActor
    @Test("T18 refresh invalidation events use all-key fallback and clear pending")
    func refreshInvalidationEventsUseAllKeyFallbackAndClearPending() async throws {
      guard #available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *) else {
        return
      }

      let harness = try ObservationChangeModel.makeHarness(
        testName: "ObservationLifecycleRefresh"
      )
      let objectID = harness.parent.objectID
      let objectIDString = objectID.cdeObservationTestID
      let observedObjects = ObservationObjectIDTable<ObservationChangeParent>()
      let buffer = ObservationChangeBuffer()
      let token = ObservationSaveToken()
      let recorder = CoreDataNotificationRecorder(
        context: harness.context,
        names: [Notification.Name.NSManagedObjectContextObjectsDidChange]
      )

      observedObjects.register(harness.parent)
      buffer.register(token: token, objectID: objectIDString, keys: ["name"])

      harness.context.refresh(harness.parent, mergeChanges: false)
      harness.context.processPendingChanges()

      let refreshSnapshot = await snapshot(
        from: recorder,
        name: Notification.Name.NSManagedObjectContextObjectsDidChange,
        containing: objectIDString
      )
      #expect(
        refreshSnapshot?.refreshedObjectIDs.contains(objectIDString) == true
          || refreshSnapshot?.invalidatedObjectIDs.contains(objectIDString) == true
      )

      let plan = ObservationLifecycleHub.refreshOrInvalidate(
        affectedObjectIDs: [objectID],
        observedObjects: observedObjects,
        buffer: buffer
      )

      #expect(plan.lookupCount == 1)
      #expect(plan.invalidations[objectIDString] == .allObservableKeyPaths)
      #expect(buffer.pendingChange(for: objectIDString) == nil)
      #expect(buffer.pendingObjectCount == 0)
      #expect(buffer.tokenCount == 0)
    }

    @MainActor
    @Test("T18 rollback clears local dirty keys and save token metadata")
    func rollbackClearsLocalDirtyKeysAndSaveTokenMetadata() throws {
      guard #available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *) else {
        return
      }

      let harness = try ObservationChangeModel.makeHarness(
        testName: "ObservationLifecycleRollback"
      )
      let objectID = harness.parent.objectID
      let objectIDString = objectID.cdeObservationTestID
      let observedObjects = ObservationObjectIDTable<ObservationChangeParent>()
      let buffer = ObservationChangeBuffer()
      let token = ObservationSaveToken()

      observedObjects.register(harness.parent)
      buffer.register(token: token, objectID: objectIDString, keys: ["name"])
      harness.parent.setValue("dirty", forKey: "name")

      #expect(harness.parent.cdeObservationPendingKeys == ["name"])

      harness.context.rollback()

      let plan = ObservationLifecycleHub.rollback(
        affectedObjectIDs: [objectID],
        observedObjects: observedObjects,
        buffer: buffer,
        tokens: [token]
      )

      #expect(plan.invalidations[objectIDString] == .allObservableKeyPaths)
      #expect(buffer.pendingChange(for: objectIDString) == nil)
      #expect(buffer.pendingObjectCount == 0)
      #expect(buffer.tokenCount == 0)
      #expect(harness.context.hasChanges == false)
      #expect(harness.parent.cdeObservationPendingKeys.isEmpty)
      #expect(harness.parent.value(forKey: "name") as? String == "parent")
    }

    @MainActor
    @Test("T18 delete and reset clean observed table and pending buffer")
    func deleteAndResetCleanObservedTableAndPendingBuffer() throws {
      guard #available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *) else {
        return
      }

      let harness = try ObservationChangeModel.makeHarness(
        testName: "ObservationLifecycleCleanup"
      )
      let deletedID = harness.parent.objectID
      let deletedIDString = deletedID.cdeObservationTestID
      let resetID = harness.secondParent.objectID
      let resetIDString = resetID.cdeObservationTestID
      let observedObjects = ObservationObjectIDTable<ObservationChangeParent>()
      let buffer = ObservationChangeBuffer()
      let token = ObservationSaveToken()

      observedObjects.register(harness.parent)
      observedObjects.register(harness.secondParent)
      buffer.register(token: token, objectID: deletedIDString, keys: ["name"])
      buffer.register(token: token, objectID: resetIDString, keys: ["name"])

      harness.context.delete(harness.parent)
      ObservationLifecycleHub.delete(
        objectIDs: [deletedID],
        observedObjects: observedObjects,
        buffer: buffer
      )

      #expect(observedObjects.contains(deletedID) == false)
      #expect(observedObjects.contains(resetID))
      #expect(buffer.pendingChange(for: deletedIDString) == nil)
      #expect(buffer.pendingChange(for: resetIDString) == .keyPaths(["name"]))
      #expect(buffer.pendingObjectCount == 1)
      #expect(buffer.tokenCount == 1)

      harness.context.reset()
      ObservationLifecycleHub.reset(observedObjects: observedObjects, buffer: buffer)

      #expect(observedObjects.liveObjectIDs.isEmpty)
      #expect(buffer.pendingObjectCount == 0)
      #expect(buffer.tokenCount == 0)
      #expect(harness.context.registeredObject(for: resetID) == nil)
    }

    @MainActor
    @Test("T18 faulted object getter re-registers observation access")
    func faultedObjectGetterReregistersObservationAccess() throws {
      guard #available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *) else {
        return
      }

      let container = try ObservationSpikeModel.makeContainer(
        testName: "ObservationLifecycleFaultAccess"
      )
      let context = container.viewContext
      let item = try ObservationSpikeModel.makeItem(in: context)
      item.name = "initial"
      try context.save()

      context.refresh(item, mergeChanges: false)
      #expect(item.isFault)

      let counter = ObservationChangeCounter()
      _ = withObservationTracking {
        item.name
      } onChange: {
        counter.increment()
      }

      #expect(item.isFault == false)

      item.invalidate(\.name)
      #expect(counter.value == 1)
    }

    @Test("T20 route cost is bounded by affected object IDs and field fan-out")
    func routeCostIsBoundedByAffectedObjectIDsAndFieldFanOut() {
      let payload = ObservationChangePayloadCost.fieldSet(
        ObservationFieldMap.mvp.fieldSet(for: ["children"])
      )
      let plan = ObservationRouteCostPlan.merge(
        affectedObjectIDCount: 3,
        emittedObjectInvalidationCount: 2,
        payload: payload
      )

      #expect(plan.lookupUnits == 3)
      #expect(plan.pendingHistoryScanUnits == 0)
      #expect(plan.relationshipTraversalUnits == 0)
      #expect(plan.emittedMutationEvents == 2)
      #expect(plan.payloadCost.storedFieldCount == 2)
    }

    @Test("T20 pending compression keeps object identity and drops per-field storage")
    func pendingCompressionKeepsObjectIdentityAndDropsPerFieldStorage() {
      let precise = ObservationChangePayloadCost.fieldSet(
        ObservationFieldSet(ObservationFieldID.allCases)
      )
      let compressed = ObservationChangePayloadCost.allObservableKeyPaths

      #expect(precise.storedFieldCount == ObservationFieldID.allCases.count)
      #expect(compressed.storedFieldCount == 0)
    }

    private func snapshot(
      from recorder: CoreDataNotificationRecorder,
      name: Notification.Name,
      containing objectID: String
    ) async -> CoreDataChangeSnapshot? {
      for _ in 0..<50 {
        if let snapshot = recorder.snapshots(for: name).last(where: {
          $0.affectedObjectIDs.contains(objectID)
        }) {
          return snapshot
        }
        try? await Task.sleep(nanoseconds: 20_000_000)
      }
      return recorder.snapshots(for: name).last(where: {
        $0.affectedObjectIDs.contains(objectID)
      })
    }
  }
#endif
