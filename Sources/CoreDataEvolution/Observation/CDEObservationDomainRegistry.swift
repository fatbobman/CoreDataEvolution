@preconcurrency import CoreData
import Foundation

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
