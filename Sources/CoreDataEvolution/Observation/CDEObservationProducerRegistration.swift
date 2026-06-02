#if compiler(>=6.2)
  @preconcurrency import CoreData
  import Foundation

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
            didInvalidate: false,
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
        return (
          didInvalidate: true,
          observerTokens: tokens,
          stagedSave: staged,
          committedTokens: committed
        )
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
      guard state.didInvalidate else {
        return
      }
      // The domain owns its registration list on MainActor; producer invalidation may happen from an
      // actor deinit or a context callback on another executor.
      Task { @MainActor [weak domain, weak self] in
        guard let self else {
          return
        }
        domain?.removeProducerRegistration(self)
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

#endif
