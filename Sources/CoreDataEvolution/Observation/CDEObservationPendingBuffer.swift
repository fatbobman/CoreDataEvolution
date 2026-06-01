@preconcurrency import CoreData
import Foundation

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
