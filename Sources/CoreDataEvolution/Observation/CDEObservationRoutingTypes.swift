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

/// Policy for suppressing the cross-cycle echo of a precise route.
///
/// A precise route is dispatched immediately; if the same change is then re-merged back into the
/// `viewContext` a run-loop turn later, that echo finds the pending consumed and widens to all-key,
/// waking unchanged-sibling readers. The runtime handles this generically from the `viewContext` merge
/// notifications and never inspects what produced the merge — re-merging is just the common behavior of
/// `NSPersistentCloudKitContainer` (which always enables Persistent History Tracking, even without a
/// configured CloudKit container), parent/child contexts, or a manual `mergeChanges`.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
public enum CDEPreciseRouteEchoSuppression: Sendable {
  /// Default heuristic: enabled for `NSPersistentCloudKitContainer` (the container that, in practice,
  /// re-merges its own saves), off otherwise so a stale marker cannot eat a later merge on a container
  /// that never echoes. Not CloudKit-specific routing — just the default-on signal.
  case auto
  /// Always enabled. Use for any setup that re-merges saves back into the `viewContext` (e.g. PHT on a
  /// plain container, or a parent/child context chain) where `.auto` would leave it off.
  case on
  /// Always disabled. Precise routes consume their pending immediately, as a non-re-merging container.
  case off
}
