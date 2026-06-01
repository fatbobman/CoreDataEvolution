@preconcurrency import CoreData
import Dispatch
import Observation
import Testing

@testable import CoreDataEvolution

@objc(ObservationRuntimeItem)
@PersistentModel(observation: .mainActor)
final class ObservationRuntimeItem: NSManagedObject {
  @Attribute(persistentName: "display_name")
  var name: String = ""

  var note: String = ""
}

@objc(ObservationRuntimeParent)
@PersistentModel(observation: .mainActor)
final class ObservationRuntimeParent: NSManagedObject {
  var name: String = ""

  @Relationship(inverse: "parent", deleteRule: .nullify)
  var children: Set<ObservationRuntimeChild>
}

@objc(ObservationRuntimeChild)
@PersistentModel(observation: .mainActor)
final class ObservationRuntimeChild: NSManagedObject {
  var name: String = ""

  @Relationship(inverse: "children", deleteRule: .nullify)
  var parent: ObservationRuntimeParent?
}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
@NSModelActor(disableGenerateInit: true)
private actor ObservationRuntimeMetadataActor {
  init(container: NSPersistentContainer) {
    modelContainer = container
    let context = container.newBackgroundContext()
    context.name = "ObservationRuntimeMetadataActor"
    modelExecutor = .init(context: context)
  }

  func updateItemName(
    id: NSManagedObjectID,
    newName: String,
    in domain: CDEObservationDomain
  ) async throws {
    let item = try requireItem(id: id)
    item.name = newName
    try await saveObservedChanges(in: domain)
  }

  func updateItemNameAfterSignal(
    id: NSManagedObjectID,
    newName: String,
    in domain: CDEObservationDomain,
    onPrepared: @Sendable () -> Void
  ) async throws {
    let item = try requireItem(id: id)
    item.name = newName
    onPrepared()
    try await saveObservedChanges(in: domain)
  }

  func updateItemNoteWithoutSave(
    id: NSManagedObjectID,
    newNote: String
  ) throws {
    let item = try requireItem(id: id)
    item.note = newNote
  }

  func updateItemNameWithDirectSave(
    id: NSManagedObjectID,
    newName: String
  ) throws {
    let item = try requireItem(id: id)
    item.name = newName
    try modelContext.save()
  }

  func updateItemNameWithFailingObservedSave(
    id: NSManagedObjectID,
    in domain: CDEObservationDomain
  ) async throws {
    let item = try requireItem(id: id)
    item.setValue(nil, forKey: "display_name")
    try await saveObservedChanges(in: domain)
  }

  func insertChildAttachedToParent(
    parentID: NSManagedObjectID,
    childName: String,
    in domain: CDEObservationDomain
  ) async throws -> NSManagedObjectID {
    let parent = try requireParent(id: parentID)
    let entity = try #require(
      NSEntityDescription.entity(forEntityName: "ObservationRuntimeChild", in: modelContext)
    )
    let child = ObservationRuntimeChild(entity: entity, insertInto: modelContext)
    child.name = childName
    child.parent = parent
    try await saveObservedChanges(in: domain)
    return child.objectID
  }

  private func requireItem(id: NSManagedObjectID) throws -> ObservationRuntimeItem {
    try #require(
      try modelContext.existingObject(with: id) as? ObservationRuntimeItem
    )
  }

  private func requireParent(id: NSManagedObjectID) throws -> ObservationRuntimeParent {
    try #require(
      try modelContext.existingObject(with: id) as? ObservationRuntimeParent
    )
  }
}

@MainActor
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
@NSMainModelActor
private final class ObservationRuntimeMainHandler {
  func updateItemName(
    id: NSManagedObjectID,
    newName: String,
    in domain: CDEObservationDomain
  ) throws {
    let item = try #require(
      try modelContext.existingObject(with: id) as? ObservationRuntimeItem
    )
    item.name = newName
    try saveObservedChanges(in: domain)
  }
}

@Suite("Observation Runtime Core", .serialized)
struct ObservationRuntimeCoreTests {
  @MainActor
  @Test("domain activation and generated getter association")
  func domainActivationAndGeneratedGetterAssociation() throws {
    guard #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *) else {
      return
    }

    let container = try makeContainer(testName: "ObservationRuntimeDomainAssociation")
    let context = container.viewContext
    let item = try makeSavedItem(in: context, name: "initial")
    let domain = CDEObservationDomain(container: container)

    #expect(CDEObservationDomainRegistry.domain(for: context) === domain)
    #expect(domain.liveObservedObjectIDs.isEmpty)

    _ = item.name
    _ = item.note

    #expect(domain.containsObservedObject(item.objectID))
    #expect(domain.liveObservedObjectIDs == [item.objectID])

    domain.invalidate()

    #expect(CDEObservationDomainRegistry.domain(for: context) == nil)
    #expect(domain.liveObservedObjectIDs.isEmpty)
  }

  @MainActor
  @Test("plain viewContext save routes the exact changed field")
  func plainViewContextSaveRoutesExactChangedField() throws {
    guard #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *) else {
      return
    }

    let container = try makeContainer(testName: "ObservationRuntimeViewContextSave")
    let context = container.viewContext
    let item = try makeSavedItem(in: context, name: "initial")
    var routed: [(NSManagedObjectID, CDEObservationInvalidationDecision)] = []
    let domain = CDEObservationDomain(container: container) { object, decision in
      routed.append((object.objectID, decision))
    }

    _ = item.name
    _ = item.note
    item.name = "renamed"
    try context.save()

    let routedChange = try #require(routed.first)
    #expect(routed.count == 1)
    #expect(routedChange.0 == item.objectID)
    #expect(paths(for: routedChange.1) == ["name"])
    #expect(domain.pendingObjectCount == 0)
    #expect(domain.pendingTokenCount == 0)
  }

  @MainActor
  @Test("main actor observed save keeps viewContext precision")
  func mainActorObservedSaveKeepsViewContextPrecision() throws {
    guard #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *) else {
      return
    }

    let container = try makeContainer(testName: "ObservationRuntimeMainActorObservedSave")
    let context = container.viewContext
    let item = try makeSavedItem(in: context, name: "initial")
    let handler = ObservationRuntimeMainHandler(modelContainer: container)
    var routed: [(NSManagedObjectID, CDEObservationInvalidationDecision)] = []
    let domain = CDEObservationDomain(container: container) { object, decision in
      routed.append((object.objectID, decision))
    }

    _ = item.name
    _ = item.note
    try handler.updateItemName(id: item.objectID, newName: "main-actor", in: domain)

    let routedChange = try #require(routed.first)
    #expect(routed.count == 1)
    #expect(routedChange.0 == item.objectID)
    #expect(paths(for: routedChange.1) == ["name"])
    #expect(domain.pendingObjectCount == 0)
    #expect(domain.pendingTokenCount == 0)
  }

  @MainActor
  @Test("background actor observed save routes exact changed field")
  func backgroundActorObservedSaveRoutesExactChangedField() async throws {
    guard #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *) else {
      return
    }

    let container = try makeContainer(testName: "ObservationRuntimeActorObservedSave")
    let context = container.viewContext
    let item = try makeSavedItem(in: context, name: "initial")
    let actor = ObservationRuntimeMetadataActor(container: container)
    var routed: [(NSManagedObjectID, CDEObservationInvalidationDecision)] = []
    let domain = CDEObservationDomain(container: container) { object, decision in
      routed.append((object.objectID, decision))
    }

    _ = item.name
    _ = item.note
    try await actor.updateItemName(id: item.objectID, newName: "actor-observed", in: domain)
    await waitForCondition { routed.isEmpty == false }

    let routedChange = try #require(routed.first)
    #expect(routed.count == 1)
    #expect(routedChange.0 == item.objectID)
    #expect(paths(for: routedChange.1) == ["name"])
    #expect(domain.pendingObjectCount == 0)
    #expect(domain.pendingTokenCount == 0)

    routed.removeAll()
    try await actor.updateItemNameWithDirectSave(id: item.objectID, newName: "direct-save")
    await waitForCondition { routed.isEmpty == false }

    let fallbackChange = try #require(routed.first)
    #expect(routed.count == 1)
    #expect(fallbackChange.0 == item.objectID)
    #expect(fallbackChange.1 == .allObservableKeyPaths)
    #expect(paths(for: fallbackChange.1) == ["*"])
  }

  @Test("background actor observed save does not suspend between staging and save")
  func backgroundActorObservedSaveDoesNotSuspendBetweenStagingAndSave() async throws {
    guard #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *) else {
      return
    }

    let prepared = DispatchSemaphore(value: 0)
    let reentrantDone = DispatchSemaphore(value: 0)
    let mainActorEntered = DispatchSemaphore(value: 0)
    let releaseMainActor = DispatchSemaphore(value: 0)
    let fixture = try await MainActor.run {
      let container = try makeContainer(testName: "ObservationRuntimeActorObservedSaveOrdering")
      let context = container.viewContext
      let item = try makeSavedItem(in: context, name: "initial")
      let actor = ObservationRuntimeMetadataActor(container: container)
      let domain = CDEObservationDomain(container: container)

      _ = item.name
      _ = item.note

      return ObservationActorSaveOrderingFixture(
        container: container,
        itemID: item.objectID,
        actor: actor,
        domain: domain
      )
    }

    let mainActorBlocker = Task { @MainActor in
      blockMainActor(entered: mainActorEntered, release: releaseMainActor)
    }

    var mainActorReleased = false
    func releaseBlockedMainActor() {
      guard mainActorReleased == false else {
        return
      }
      mainActorReleased = true
      releaseMainActor.signal()
    }
    defer {
      releaseBlockedMainActor()
    }
    guard waitSynchronously(for: mainActorEntered, timeout: .now() + 15) == .success else {
      Issue.record("Timed out waiting for MainActor blocker to enter.")
      releaseBlockedMainActor()
      _ = await mainActorBlocker.result
      await fixture.releaseDomain()
      return
    }

    let saveTask = Task.detached {
      try await fixture.actor.updateItemNameAfterSignal(
        id: fixture.itemID,
        newName: "actor-observed",
        in: fixture.domain
      ) {
        prepared.signal()
      }
    }
    guard waitSynchronously(for: prepared, timeout: .now() + 15) == .success else {
      Issue.record("Timed out waiting for actor save to reach the pre-save point.")
      releaseBlockedMainActor()
      _ = await mainActorBlocker.result
      _ = try? await saveTask.value
      await fixture.releaseDomain()
      return
    }

    // The blocker keeps MainActor unavailable after the actor job reaches its pre-save point. The
    // old async MainActor staging hop would suspend there and allow this reentrant job to mutate
    // the same context before save; the synchronous producer path saves before reentrancy.
    let reentrantTask = Task.detached {
      try await fixture.actor.updateItemNoteWithoutSave(
        id: fixture.itemID,
        newNote: "reentrant-note"
      )
      reentrantDone.signal()
    }
    guard waitSynchronously(for: reentrantDone, timeout: .now() + 15) == .success else {
      Issue.record("Timed out waiting for the reentrant actor job.")
      releaseBlockedMainActor()
      _ = await mainActorBlocker.result
      _ = try? await saveTask.value
      _ = try? await reentrantTask.value
      await fixture.releaseDomain()
      return
    }

    releaseBlockedMainActor()
    _ = await mainActorBlocker.result
    do {
      try await saveTask.value
      try await reentrantTask.value

      let persistedNote = try await readItemNote(container: fixture.container, id: fixture.itemID)
      #expect(persistedNote == "note")
      await fixture.releaseDomain()
    } catch {
      await fixture.releaseDomain()
      throw error
    }
  }

  @MainActor
  @Test("producer precise route suppresses same-cycle duplicate fallback")
  func producerPreciseRouteSuppressesSameCycleDuplicateFallback() throws {
    guard #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *) else {
      return
    }

    let container = try makeContainer(testName: "ObservationRuntimeSameCyclePreciseFallback")
    let context = container.viewContext
    let item = try makeSavedItem(in: context, name: "initial")
    let itemID = item.objectID
    let token = CDEObservationSaveToken()
    let nameSet = fieldSet(for: ["display_name"])
    var routed: [(NSManagedObjectID, CDEObservationInvalidationDecision)] = []
    let domain = CDEObservationDomain(container: container) { object, decision in
      routed.append((object.objectID, decision))
    }

    _ = item.name
    _ = item.note
    domain.stagePendingChangesFromProducer(
      token: token,
      changesByObjectID: [itemID: nameSet]
    )

    let precisePlan = domain.routeMerge(affectedObjectIDs: [itemID])
    let preciseRoutedObjectIDs = Set(
      precisePlan.decisionsByObjectID.compactMap { objectID, decision in
        if case .fieldSet = decision {
          return objectID
        }
        return nil
      }
    )
    let refreshFallbackPlan = domain.routeAllKeyFallback(
      affectedObjectIDs: [itemID],
      suppressingObjectIDs: preciseRoutedObjectIDs,
      skipsProducerBackedPrecise: true
    )
    let duplicateMergePlan = domain.routeMerge(affectedObjectIDs: [itemID])
    let duplicateRefreshFallbackPlan = domain.routeAllKeyFallback(
      affectedObjectIDs: [itemID],
      suppressingObjectIDs: duplicateMergePlan.sameCycleSuppressedObjectIDs,
      skipsProducerBackedPrecise: true
    )
    let laterFallbackPlan = domain.routeMerge(affectedObjectIDs: [itemID])

    #expect(precisePlan.decisionsByObjectID[itemID] == .fieldSet(nameSet))
    #expect(refreshFallbackPlan.lookupCount == 1)
    #expect(refreshFallbackPlan.decisionsByObjectID.isEmpty)
    #expect(duplicateMergePlan.lookupCount == 1)
    #expect(duplicateMergePlan.decisionsByObjectID.isEmpty)
    #expect(duplicateMergePlan.sameCycleSuppressedObjectIDs == [itemID])
    #expect(duplicateRefreshFallbackPlan.lookupCount == 1)
    #expect(duplicateRefreshFallbackPlan.decisionsByObjectID.isEmpty)
    #expect(laterFallbackPlan.lookupCount == 1)
    #expect(laterFallbackPlan.decisionsByObjectID[itemID] == .allObservableKeyPaths)
    #expect(routed.count == 2)
    #expect(routed.first?.0 == itemID)
    #expect(paths(for: try #require(routed.first?.1)) == ["name"])
    #expect(routed.last?.0 == itemID)
    #expect(routed.last?.1 == .allObservableKeyPaths)
    #expect(domain.pendingObjectCount == 0)
    #expect(domain.pendingTokenCount == 0)
  }

  @MainActor
  @Test("same-cycle precision guard clears when the run loop drains")
  func sameCyclePrecisionGuardClearsWhenRunLoopDrains() async throws {
    guard #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *) else {
      return
    }

    let container = try makeContainer(testName: "ObservationRuntimeSameCycleDrain")
    let context = container.viewContext
    let item = try makeSavedItem(in: context, name: "initial")
    let itemID = item.objectID
    let token = CDEObservationSaveToken()
    let nameSet = fieldSet(for: ["display_name"])
    let domain = CDEObservationDomain(container: container)

    _ = item.name
    _ = item.note
    domain.stagePendingChangesFromProducer(token: token, changesByObjectID: [itemID: nameSet])

    // A precise merge arms the guard synchronously so a same-cycle duplicate merge / refresh echo is
    // suppressed.
    domain.routeMerge(affectedObjectIDs: [itemID])
    #expect(domain.sameCyclePrecisionGuardCount == 1)

    // The guard is cleared by a `kCFRunLoopBeforeWaiting` observer, not flushed by hand: once the
    // run loop drains the current burst and is about to sleep, the guard must be gone, so the *next*
    // save is never wrongly suppressed. This is the invariant that removed the `Task.yield()` race.
    await waitForCondition { domain.sameCyclePrecisionGuardCount == 0 }
    #expect(domain.sameCyclePrecisionGuardCount == 0)
  }

  @MainActor
  @Test("local viewContext save suppresses its cross-cycle merge echo")
  func localViewContextSaveSuppressesCrossCycleMergeEcho() async throws {
    guard #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *) else {
      return
    }

    let container = try makeContainer(testName: "ObservationRuntimeLocalSaveEcho")
    let context = container.viewContext
    let item = try makeSavedItem(in: context, name: "initial")
    let itemID = item.objectID
    var routed: [(NSManagedObjectID, CDEObservationInvalidationDecision)] = []
    let domain = CDEObservationDomain(
      container: container,
      localSaveEchoSuppression: .on
    ) { object, decision in
      routed.append((object.objectID, decision))
    }
    #expect(domain.isLocalSaveEchoSuppressionActive)

    _ = item.name
    _ = item.note

    // Real local save: precise-dispatch `name` at didSave and arm the echo marker.
    item.name = "renamed"
    try context.save()
    #expect(routed.count == 1)
    #expect(paths(for: try #require(routed.first?.1)) == ["name"])
    #expect(domain.localSaveEchoMarkerCount == 1)

    // Cross-cycle: drain the run loop. The un-honored marker must SURVIVE (this is what the
    // `beforeWaiting` boundary could not do for the same-cycle guard).
    await drainRunLoopForEchoWindow()
    #expect(domain.localSaveEchoMarkerCount == 1)

    // The CloudKit/PHT echo merge (object listed as updated) must skip, not widen to all-key.
    let echoMerge = domain.routeMerge(affectedObjectIDs: [itemID], source: "didMergeObjectIDs")
    #expect(echoMerge.decisionsByObjectID[itemID] == nil)
    #expect(routed.count == 1)

    // Once honored, the next drain clears the marker.
    await waitForCondition { domain.localSaveEchoMarkerCount == 0 }
    #expect(domain.localSaveEchoMarkerCount == 0)

    // A later, genuinely foreign merge of the same object now falls back to all-key.
    let foreignMerge = domain.routeMerge(affectedObjectIDs: [itemID], source: "didMergeObjectIDs")
    #expect(foreignMerge.decisionsByObjectID[itemID] == .allObservableKeyPaths)
    #expect(routed.last?.1 == .allObservableKeyPaths)
  }

  @MainActor
  @Test("local-save echo suppression off falls back to all-key on the echo")
  func localSaveEchoSuppressionOffFallsBackToAllKey() async throws {
    guard #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *) else {
      return
    }

    let container = try makeContainer(testName: "ObservationRuntimeLocalSaveEchoOff")
    let context = container.viewContext
    let item = try makeSavedItem(in: context, name: "initial")
    let itemID = item.objectID
    var routed: [(NSManagedObjectID, CDEObservationInvalidationDecision)] = []
    let domain = CDEObservationDomain(
      container: container,
      localSaveEchoSuppression: .off
    ) { object, decision in
      routed.append((object.objectID, decision))
    }
    #expect(domain.isLocalSaveEchoSuppressionActive == false)

    _ = item.name
    _ = item.note
    item.name = "renamed"
    try context.save()

    // No marker is armed when suppression is off; the same-cycle guard is used instead.
    #expect(domain.localSaveEchoMarkerCount == 0)
    await waitForCondition { domain.sameCyclePrecisionGuardCount == 0 }

    // A cross-cycle echo therefore widens to all-key (the legacy behavior, opt-out preserved).
    let echoMerge = domain.routeMerge(affectedObjectIDs: [itemID], source: "didMergeObjectIDs")
    #expect(echoMerge.decisionsByObjectID[itemID] == .allObservableKeyPaths)
  }

  @MainActor
  @Test("background precise route arms the cross-cycle marker when enabled")
  func backgroundPreciseRouteArmsCrossCycleMarkerWhenEnabled() throws {
    guard #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *) else {
      return
    }

    let container = try makeContainer(testName: "ObservationRuntimeBackgroundArmsMarker")
    let context = container.viewContext
    let item = try makeSavedItem(in: context, name: "initial")
    let itemID = item.objectID
    let token = CDEObservationSaveToken()
    let nameSet = fieldSet(for: ["display_name"])
    let domain = CDEObservationDomain(container: container, localSaveEchoSuppression: .on)

    _ = item.name
    _ = item.note
    domain.stagePendingChangesFromProducer(token: token, changesByObjectID: [itemID: nameSet])

    // With suppression enabled, a background/merge precise route also echoes back cross-cycle, so it
    // arms the cross-cycle marker (not the same-cycle guard, which only survives by luck across a
    // run-loop sleep).
    let plan = domain.routeMerge(affectedObjectIDs: [itemID], source: "didMergeObjectIDs")
    #expect(plan.decisionsByObjectID[itemID] == .fieldSet(nameSet))
    #expect(domain.localSaveEchoMarkerCount == 1)
    #expect(domain.sameCyclePrecisionGuardCount == 0)
  }

  @MainActor
  @Test("background precise merge suppresses its cross-cycle echo")
  func backgroundPreciseMergeSuppressesCrossCycleEcho() async throws {
    guard #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *) else {
      return
    }

    // Issue #12 refinement ③, confirmed on device: a background save echoes back ~93ms later (cross
    // run-loop sleep), so the same-cycle guard cannot reliably catch it — the cross-cycle marker must.
    let container = try makeContainer(testName: "ObservationRuntimeBackgroundCrossCycleEcho")
    let context = container.viewContext
    let item = try makeSavedItem(in: context, name: "initial")
    let itemID = item.objectID
    let token = CDEObservationSaveToken()
    let nameSet = fieldSet(for: ["display_name"])
    var routed: [(NSManagedObjectID, CDEObservationInvalidationDecision)] = []
    let domain = CDEObservationDomain(
      container: container,
      localSaveEchoSuppression: .on
    ) { object, decision in
      routed.append((object.objectID, decision))
    }

    _ = item.name
    _ = item.note
    domain.stagePendingChangesFromProducer(token: token, changesByObjectID: [itemID: nameSet])

    // Primary merge: precise dispatch + arm the cross-cycle marker.
    let primary = domain.routeMerge(affectedObjectIDs: [itemID], source: "didMergeObjectIDs")
    #expect(primary.decisionsByObjectID[itemID] == .fieldSet(nameSet))
    #expect(domain.localSaveEchoMarkerCount == 1)
    #expect(domain.sameCyclePrecisionGuardCount == 0)
    #expect(routed.count == 1)

    // Cross-cycle: drain. The un-honored marker must survive (the same-cycle guard would not).
    await drainRunLoopForEchoWindow()
    #expect(domain.localSaveEchoMarkerCount == 1)

    // The later echo merge skips instead of widening to all-key.
    let echo = domain.routeMerge(affectedObjectIDs: [itemID], source: "didMergeObjectIDs")
    #expect(echo.decisionsByObjectID[itemID] == nil)
    #expect(routed.count == 1)

    // Once honored and cleared, a genuinely foreign merge falls back to all-key.
    await waitForCondition { domain.localSaveEchoMarkerCount == 0 }
    let foreign = domain.routeMerge(affectedObjectIDs: [itemID], source: "didMergeObjectIDs")
    #expect(foreign.decisionsByObjectID[itemID] == .allObservableKeyPaths)
    #expect(routed.last?.1 == .allObservableKeyPaths)
  }

  @MainActor
  @Test("consecutive local saves of the same object do not eat each other")
  func consecutiveLocalSavesOfSameObjectDoNotEatEachOther() async throws {
    guard #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *) else {
      return
    }

    let container = try makeContainer(testName: "ObservationRuntimeLocalSaveConsecutive")
    let context = container.viewContext
    let item = try makeSavedItem(in: context, name: "initial")
    let itemID = item.objectID
    var routed: [(NSManagedObjectID, CDEObservationInvalidationDecision)] = []
    let domain = CDEObservationDomain(
      container: container,
      localSaveEchoSuppression: .on
    ) { object, decision in
      routed.append((object.objectID, decision))
    }

    _ = item.name
    _ = item.note

    item.name = "first"
    try context.save()
    #expect(domain.localSaveEchoMarkerCount == 1)

    // Second save before the first echo: willSave clears the stale marker, didSave re-arms a fresh
    // one. Both saves dispatch precisely; neither is swallowed.
    item.name = "second"
    try context.save()
    #expect(domain.localSaveEchoMarkerCount == 1)
    #expect(routed.count == 2)
    #expect(paths(for: try #require(routed.last?.1)) == ["name"])

    // The fresh marker still suppresses the echo of the second save.
    let echoMerge = domain.routeMerge(affectedObjectIDs: [itemID], source: "didMergeObjectIDs")
    #expect(echoMerge.decisionsByObjectID[itemID] == nil)
    #expect(routed.count == 2)
  }

  @MainActor
  @Test("local-save echo suppression policy resolves from container and override")
  func localSaveEchoSuppressionPolicyResolves() throws {
    guard #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *) else {
      return
    }

    let container = try makeContainer(testName: "ObservationRuntimeLocalSaveEchoPolicy")
    _ = container.viewContext

    let auto = CDEObservationDomain(container: container, localSaveEchoSuppression: .auto)
    // Plain NSPersistentContainer is not a CloudKit container, so `.auto` resolves off.
    #expect(auto.isLocalSaveEchoSuppressionActive == false)
    auto.invalidate()

    let forcedOn = CDEObservationDomain(container: container, localSaveEchoSuppression: .on)
    #expect(forcedOn.isLocalSaveEchoSuppressionActive)
    forcedOn.invalidate()

    let forcedOff = CDEObservationDomain(container: container, localSaveEchoSuppression: .off)
    #expect(forcedOff.isLocalSaveEchoSuppressionActive == false)
    forcedOff.invalidate()
  }

  @MainActor
  @Test("background actor observed save failure rolls back staged token")
  func backgroundActorObservedSaveFailureRollsBackStagedToken() async throws {
    guard #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *) else {
      return
    }

    let container = try makeContainer(testName: "ObservationRuntimeActorObservedSaveFailure")
    let context = container.viewContext
    let item = try makeSavedItem(in: context, name: "initial")
    let actor = ObservationRuntimeMetadataActor(container: container)
    let domain = CDEObservationDomain(container: container)

    _ = item.name
    do {
      try await actor.updateItemNameWithFailingObservedSave(id: item.objectID, in: domain)
      Issue.record("Expected save failure for nil non-optional display_name.")
    } catch {
      #expect(domain.pendingObjectCount == 0)
      #expect(domain.pendingTokenCount == 0)
    }
  }

  @MainActor
  @Test("background actor observed relationship save invalidates owner relationship and count")
  func backgroundActorObservedRelationshipSaveInvalidatesOwnerRelationshipAndCount()
    async throws
  {
    guard #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *) else {
      return
    }

    let container = try makeRelationshipContainer(
      testName: "ObservationRuntimeActorObservedRelationshipSave"
    )
    let context = container.viewContext
    let parent = try makeSavedParent(in: context, name: "parent")
    let actor = ObservationRuntimeMetadataActor(container: container)
    let domain = CDEObservationDomain(container: container)
    let childrenCounter = ObservationChangeCounter()
    let countCounter = ObservationChangeCounter()
    let nameCounter = ObservationChangeCounter()

    _ = withObservationTracking {
      parent.children
    } onChange: {
      childrenCounter.increment()
    }
    _ = withObservationTracking {
      parent.childrenCount
    } onChange: {
      countCounter.increment()
    }
    _ = withObservationTracking {
      parent.name
    } onChange: {
      nameCounter.increment()
    }

    let childID = try await actor.insertChildAttachedToParent(
      parentID: parent.objectID,
      childName: "child",
      in: domain
    )
    await waitForCondition {
      childrenCounter.value == 1 && countCounter.value == 1
    }

    #expect(childID.isTemporaryID == false)
    #expect(childrenCounter.value == 1)
    #expect(countCounter.value == 1)
    #expect(nameCounter.value == 0)
    #expect(domain.pendingObjectCount == 0)
    #expect(domain.pendingTokenCount == 0)
  }

  @MainActor
  @Test("registered ordinary background context direct save routes exact changed field")
  func registeredOrdinaryBackgroundContextDirectSaveRoutesExactChangedField() async throws {
    guard #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *) else {
      return
    }

    let container = try makeContainer(testName: "ObservationRuntimeRegisteredContextAutomatic")
    let context = container.viewContext
    let item = try makeSavedItem(in: context, name: "initial")
    let itemID = item.objectID
    let background = container.newBackgroundContext()
    var routed: [(NSManagedObjectID, CDEObservationInvalidationDecision)] = []
    let domain = CDEObservationDomain(container: container) { object, decision in
      routed.append((object.objectID, decision))
    }
    let registration = domain.registerChangeProducer(context: background)

    _ = item.name
    _ = item.note
    try await background.perform {
      let backgroundItem = try #require(
        try background.existingObject(with: itemID) as? ObservationRuntimeItem
      )
      backgroundItem.name = "ordinary-registered"
      try background.save()
    }
    await waitForCondition { routed.isEmpty == false }

    let routedChange = try #require(routed.first)
    #expect(registration.isObserving)
    #expect(routed.count == 1)
    #expect(routedChange.0 == itemID)
    #expect(paths(for: routedChange.1) == ["name"])
    #expect(domain.pendingObjectCount == 0)
    #expect(domain.pendingTokenCount == 0)
  }

  @MainActor
  @Test("unregistered ordinary background context falls back to all-key")
  func unregisteredOrdinaryBackgroundContextFallsBackToAllKey() async throws {
    guard #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *) else {
      return
    }

    let container = try makeContainer(testName: "ObservationRuntimeUnregisteredContextFallback")
    let context = container.viewContext
    let item = try makeSavedItem(in: context, name: "initial")
    let itemID = item.objectID
    let background = container.newBackgroundContext()
    var routed: [(NSManagedObjectID, CDEObservationInvalidationDecision)] = []
    let domain = CDEObservationDomain(container: container) { object, decision in
      routed.append((object.objectID, decision))
    }

    _ = item.name
    _ = item.note
    try await background.perform {
      let backgroundItem = try #require(
        try background.existingObject(with: itemID) as? ObservationRuntimeItem
      )
      backgroundItem.name = "ordinary-unregistered"
      try background.save()
    }
    await waitForCondition { routed.isEmpty == false }

    #expect(routed.isEmpty == false)
    #expect(
      routed.allSatisfy { objectID, decision in
        objectID == itemID && decision == .allObservableKeyPaths
      }
    )
    #expect(routed.contains { _, decision in paths(for: decision) == ["*"] })
    #expect(domain.pendingObjectCount == 0)
  }

  @MainActor
  @Test("registered ordinary background context supports manual merge consumption")
  func registeredOrdinaryBackgroundContextSupportsManualMergeConsumption() async throws {
    guard #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *) else {
      return
    }

    let container = try makeContainer(
      testName: "ObservationRuntimeRegisteredContextManual",
      automaticallyMergesChangesFromParent: false
    )
    let context = container.viewContext
    let item = try makeSavedItem(in: context, name: "initial")
    let itemID = item.objectID
    let background = container.newBackgroundContext()
    let saveRecorder = ObservationNotificationRecorder(
      context: background,
      name: Notification.Name.NSManagedObjectContextDidSave
    )
    var routed: [(NSManagedObjectID, CDEObservationInvalidationDecision)] = []
    let domain = CDEObservationDomain(container: container) { object, decision in
      routed.append((object.objectID, decision))
    }
    let registration = domain.registerChangeProducer(context: background)

    _ = item.name
    _ = item.note
    try await background.perform {
      let backgroundItem = try #require(
        try background.existingObject(with: itemID) as? ObservationRuntimeItem
      )
      backgroundItem.name = "ordinary-manual"
      try background.save()
    }

    let saveNotification = try #require(saveRecorder.lastNotification)
    context.mergeChanges(fromContextDidSave: saveNotification)
    context.processPendingChanges()
    await waitForCondition { routed.isEmpty == false }

    let routedChange = try #require(routed.first)
    #expect(registration.isObserving)
    #expect(routed.count == 1)
    #expect(routedChange.0 == itemID)
    #expect(paths(for: routedChange.1) == ["name"])
    #expect(domain.pendingObjectCount == 0)
    #expect(domain.pendingTokenCount == 0)
  }

  @MainActor
  @Test("registered ordinary contexts keep producer and container scope")
  func registeredOrdinaryContextsKeepProducerAndContainerScope() async throws {
    guard #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *) else {
      return
    }

    let first = try makeContainer(
      testName: "ObservationRuntimeRegisteredScopeFirst",
      automaticallyMergesChangesFromParent: false
    )
    let firstContext = first.viewContext
    let firstItem = try makeSavedItem(in: firstContext, name: "first")
    let secondItem = try makeSavedItem(in: firstContext, name: "second")
    let firstItemID = firstItem.objectID
    let secondItemID = secondItem.objectID
    let firstDomain = CDEObservationDomain(container: first)
    let firstBackgroundA = first.newBackgroundContext()
    let firstBackgroundB = first.newBackgroundContext()
    let firstRegistrationA = firstDomain.registerChangeProducer(context: firstBackgroundA)
    let firstRegistrationB = firstDomain.registerChangeProducer(context: firstBackgroundB)
    let nameSet = fieldSet(for: ["display_name"])

    try await firstBackgroundA.perform {
      let item = try #require(
        try firstBackgroundA.existingObject(with: firstItemID) as? ObservationRuntimeItem
      )
      item.name = "scope-a"
      try firstBackgroundA.save()
    }
    try await firstBackgroundB.perform {
      let item = try #require(
        try firstBackgroundB.existingObject(with: secondItemID) as? ObservationRuntimeItem
      )
      item.name = "scope-b"
      try firstBackgroundB.save()
    }

    #expect(firstDomain.pendingChange(for: firstItemID) == .fieldSet(nameSet))
    #expect(firstDomain.pendingChange(for: secondItemID) == .fieldSet(nameSet))
    #expect(firstDomain.pendingObjectCount == 2)
    #expect(firstDomain.pendingTokenCount == 2)

    firstRegistrationA.invalidate()

    #expect(firstDomain.pendingChange(for: firstItemID) == nil)
    #expect(firstDomain.pendingChange(for: secondItemID) == .fieldSet(nameSet))
    #expect(firstDomain.pendingObjectCount == 1)
    #expect(firstDomain.pendingTokenCount == 1)
    #expect(firstRegistrationA.isObserving == false)
    #expect(firstRegistrationB.isObserving)

    let other = try makeContainer(
      testName: "ObservationRuntimeRegisteredScopeOther",
      automaticallyMergesChangesFromParent: false
    )
    let otherContext = other.viewContext
    let otherItem = try makeSavedItem(in: otherContext, name: "other")
    let otherItemID = otherItem.objectID
    let otherDomain = CDEObservationDomain(container: other)
    let otherBackground = other.newBackgroundContext()
    let otherRegistration = otherDomain.registerChangeProducer(context: otherBackground)

    try await otherBackground.perform {
      let item = try #require(
        try otherBackground.existingObject(with: otherItemID) as? ObservationRuntimeItem
      )
      item.name = "scope-other"
      try otherBackground.save()
    }

    #expect(firstDomain.pendingChange(for: otherItemID) == nil)
    #expect(otherDomain.pendingChange(for: otherItemID) == .fieldSet(nameSet))
    #expect(otherRegistration.isObserving)
  }

  @MainActor
  @Test("registered ordinary context cleans failure reset and invalidation state")
  func registeredOrdinaryContextCleansFailureResetAndInvalidationState() async throws {
    guard #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *) else {
      return
    }

    let container = try makeContainer(
      testName: "ObservationRuntimeRegisteredContextCleanup",
      automaticallyMergesChangesFromParent: false
    )
    let context = container.viewContext
    let item = try makeSavedItem(in: context, name: "initial")
    let secondItem = try makeSavedItem(in: context, name: "second")
    let itemID = item.objectID
    let secondItemID = secondItem.objectID
    let background = container.newBackgroundContext()
    let domain = CDEObservationDomain(container: container)
    let registration = domain.registerChangeProducer(context: background)
    let nameSet = fieldSet(for: ["display_name"])

    try await background.perform {
      let backgroundItem = try #require(
        try background.existingObject(with: itemID) as? ObservationRuntimeItem
      )
      backgroundItem.name = "cleanup-success"
      try background.save()
    }

    #expect(domain.pendingChange(for: itemID) == .fieldSet(nameSet))
    #expect(domain.pendingObjectCount == 1)
    #expect(domain.pendingTokenCount == 1)

    await background.perform {
      do {
        let backgroundItem = try background.existingObject(with: secondItemID)
        backgroundItem.setValue(nil, forKey: "display_name")
        try background.save()
        Issue.record("Expected save failure for nil non-optional display_name.")
      } catch {
        background.rollback()
      }
    }

    #expect(domain.pendingChange(for: itemID) == .fieldSet(nameSet))
    #expect(domain.pendingChange(for: secondItemID) == nil)
    #expect(domain.pendingObjectCount == 1)
    #expect(domain.pendingTokenCount == 1)
    #expect(registration.stagedSaveCount == 0)

    await background.perform {
      background.reset()
    }

    #expect(domain.pendingObjectCount == 0)
    #expect(domain.pendingTokenCount == 0)

    try await background.perform {
      let backgroundItem = try #require(
        try background.existingObject(with: itemID) as? ObservationRuntimeItem
      )
      backgroundItem.name = "cleanup-invalidate"
      try background.save()
    }

    #expect(domain.pendingChange(for: itemID) == .fieldSet(nameSet))

    registration.invalidate()

    #expect(registration.isObserving == false)
    #expect(domain.pendingObjectCount == 0)
    #expect(domain.pendingTokenCount == 0)
  }

  @MainActor
  @Test("context save wrapper keeps precision and rolls back token on throw")
  func contextSaveWrapperKeepsPrecisionAndRollsBackTokenOnThrow() async throws {
    guard #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *) else {
      return
    }

    let container = try makeContainer(testName: "ObservationRuntimeContextSaveWrapper")
    let context = container.viewContext
    let item = try makeSavedItem(in: context, name: "initial")
    let itemID = item.objectID
    let background = container.newBackgroundContext()
    var routed: [(NSManagedObjectID, CDEObservationInvalidationDecision)] = []
    let domain = CDEObservationDomain(container: container) { object, decision in
      routed.append((object.objectID, decision))
    }

    _ = item.name
    _ = item.note
    try await background.perform {
      let backgroundItem = try #require(
        try background.existingObject(with: itemID) as? ObservationRuntimeItem
      )
      backgroundItem.name = "wrapper-success"
    }
    try await domain.saveObservedChanges(in: background)
    await waitForCondition { routed.isEmpty == false }

    let routedChange = try #require(routed.first)
    #expect(routed.count == 1)
    #expect(routedChange.0 == itemID)
    #expect(paths(for: routedChange.1) == ["name"])
    #expect(domain.pendingObjectCount == 0)
    #expect(domain.pendingTokenCount == 0)

    try await background.perform {
      let backgroundItem = try #require(
        try background.existingObject(with: itemID) as? ObservationRuntimeItem
      )
      backgroundItem.setValue(nil, forKey: "display_name")
    }

    do {
      try await domain.saveObservedChanges(in: background)
      Issue.record("Expected save failure for nil non-optional display_name.")
    } catch {
      #expect(domain.pendingObjectCount == 0)
      #expect(domain.pendingTokenCount == 0)
    }
  }

  @MainActor
  @Test("explicit refresh uses all-key fallback and clears pending metadata")
  func explicitRefreshUsesAllKeyFallbackAndClearsPendingMetadata() throws {
    guard #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *) else {
      return
    }

    let container = try makeContainer(testName: "ObservationRuntimeLifecycleRefresh")
    let context = container.viewContext
    let item = try makeSavedItem(in: context, name: "initial")
    let itemID = item.objectID
    var routed: [(NSManagedObjectID, CDEObservationInvalidationDecision)] = []
    let domain = CDEObservationDomain(container: container) { object, decision in
      routed.append((object.objectID, decision))
    }
    let token = CDEObservationSaveToken()

    _ = item.name
    _ = item.note
    domain.stagePendingChange(
      token: token,
      objectID: itemID,
      fieldSet: fieldSet(for: ["display_name"])
    )

    context.refresh(item, mergeChanges: false)
    context.processPendingChanges()

    let routedChange = try #require(routed.first)
    #expect(routed.count == 1)
    #expect(routedChange.0 == itemID)
    #expect(routedChange.1 == .allObservableKeyPaths)
    #expect(domain.pendingChange(for: itemID) == nil)
    #expect(domain.pendingObjectCount == 0)
    #expect(domain.pendingTokenCount == 0)
    #expect(domain.containsObservedObject(itemID))
  }

  @MainActor
  @Test("rollback uses all-key fallback and clears pending metadata")
  func rollbackUsesAllKeyFallbackAndClearsPendingMetadata() throws {
    guard #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *) else {
      return
    }

    let container = try makeContainer(testName: "ObservationRuntimeLifecycleRollback")
    let context = container.viewContext
    let item = try makeSavedItem(in: context, name: "initial")
    let itemID = item.objectID
    var routed: [(NSManagedObjectID, CDEObservationInvalidationDecision)] = []
    let domain = CDEObservationDomain(container: container) { object, decision in
      routed.append((object.objectID, decision))
    }
    let token = CDEObservationSaveToken()

    _ = item.name
    _ = item.note
    domain.stagePendingChange(
      token: token,
      objectID: itemID,
      fieldSet: fieldSet(for: ["display_name"])
    )
    item.name = "dirty"

    #expect(context.hasChanges)

    domain.rollbackObservedChanges()

    #expect(routed.isEmpty == false)
    #expect(
      routed.allSatisfy { objectID, decision in
        objectID == itemID && decision == .allObservableKeyPaths
      }
    )
    #expect(domain.pendingChange(for: itemID) == nil)
    #expect(domain.pendingObjectCount == 0)
    #expect(domain.pendingTokenCount == 0)
    #expect(domain.containsObservedObject(itemID))
    #expect(context.hasChanges == false)
    #expect(item.name == "initial")
  }

  @MainActor
  @Test("local delete cleans routing state without invalidating deleted instance")
  func localDeleteCleansRoutingStateWithoutInvalidatingDeletedInstance() throws {
    guard #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *) else {
      return
    }

    let container = try makeContainer(testName: "ObservationRuntimeLifecycleDelete")
    let context = container.viewContext
    let deleted = try makeSavedItem(in: context, name: "deleted")
    let remaining = try makeSavedItem(in: context, name: "remaining")
    let deletedID = deleted.objectID
    let remainingID = remaining.objectID
    var routed: [(NSManagedObjectID, CDEObservationInvalidationDecision)] = []
    let domain = CDEObservationDomain(container: container) { object, decision in
      routed.append((object.objectID, decision))
    }
    let token = CDEObservationSaveToken()
    let nameSet = fieldSet(for: ["display_name"])

    _ = deleted.name
    _ = remaining.name
    domain.stagePendingChange(token: token, objectID: deletedID, fieldSet: nameSet)
    domain.stagePendingChange(token: token, objectID: remainingID, fieldSet: nameSet)

    context.delete(deleted)
    context.processPendingChanges()

    #expect(routed.isEmpty)
    #expect(domain.containsObservedObject(deletedID) == false)
    #expect(domain.containsObservedObject(remainingID))
    #expect(domain.pendingChange(for: deletedID) == nil)
    #expect(domain.pendingChange(for: remainingID) == .fieldSet(nameSet))
    #expect(domain.pendingObjectCount == 1)
    #expect(domain.pendingTokenCount == 1)
  }

  @MainActor
  @Test("reset clears observed table and pending metadata without per-object invalidation")
  func resetClearsObservedTableAndPendingMetadataWithoutPerObjectInvalidation() throws {
    guard #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *) else {
      return
    }

    let container = try makeContainer(testName: "ObservationRuntimeLifecycleReset")
    let context = container.viewContext
    let first = try makeSavedItem(in: context, name: "first")
    let second = try makeSavedItem(in: context, name: "second")
    var routed: [(NSManagedObjectID, CDEObservationInvalidationDecision)] = []
    let domain = CDEObservationDomain(container: container) { object, decision in
      routed.append((object.objectID, decision))
    }
    let token = CDEObservationSaveToken()
    let nameSet = fieldSet(for: ["display_name"])

    _ = first.name
    _ = second.name
    domain.stagePendingChange(token: token, objectID: first.objectID, fieldSet: nameSet)
    domain.stagePendingChange(token: token, objectID: second.objectID, fieldSet: nameSet)

    context.reset()

    #expect(routed.isEmpty)
    #expect(domain.liveObservedObjectIDs.isEmpty)
    #expect(domain.pendingObjectCount == 0)
    #expect(domain.pendingTokenCount == 0)
  }

  @MainActor
  @Test("faulted object getter keeps observation registration usable")
  func faultedObjectGetterKeepsObservationRegistrationUsable() throws {
    guard #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *) else {
      return
    }

    let container = try makeContainer(testName: "ObservationRuntimeLifecycleFault")
    let context = container.viewContext
    let item = try makeSavedItem(in: context, name: "initial")
    let itemID = item.objectID
    let domain = CDEObservationDomain(container: container)

    _ = item.name
    context.refresh(item, mergeChanges: false)
    #expect(item.isFault)
    #expect(domain.containsObservedObject(itemID))

    _ = item.name

    #expect(item.isFault == false)
    #expect(domain.containsObservedObject(itemID))
  }

  @MainActor
  @Test("viewContext save rekeys observed temporary object IDs")
  func viewContextSaveRekeysObservedTemporaryObjectIDs() throws {
    guard #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *) else {
      return
    }

    let container = try makeContainer(testName: "ObservationRuntimeTemporaryRekey")
    let context = container.viewContext
    let item = try makeUnsavedItem(in: context, name: "temporary")
    let temporaryID = item.objectID
    let domain = CDEObservationDomain(container: container)

    #expect(temporaryID.isTemporaryID)
    _ = item.name
    #expect(domain.containsObservedObject(temporaryID))

    try context.save()

    #expect(item.objectID.isTemporaryID == false)
    #expect(domain.containsObservedObject(temporaryID) == false)
    #expect(domain.containsObservedObject(item.objectID))
  }

  @MainActor
  @Test("batch update object IDs route all-key fallback")
  func batchUpdateObjectIDsRouteAllKeyFallback() async throws {
    guard #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *) else {
      return
    }

    let container = try makeContainer(
      testName: "ObservationRuntimeBatchUpdate",
      automaticallyMergesChangesFromParent: false
    )
    let context = container.viewContext
    let item = try makeSavedItem(in: context, name: "initial")
    let itemID = item.objectID
    let background = container.newBackgroundContext()
    var routed: [(NSManagedObjectID, CDEObservationInvalidationDecision)] = []
    let domain = CDEObservationDomain(container: container) { object, decision in
      routed.append((object.objectID, decision))
    }

    _ = item.name
    _ = item.note
    let updatedIDs = try await background.perform {
      let request = NSBatchUpdateRequest(entityName: "ObservationRuntimeItem")
      request.predicate = NSPredicate(format: "display_name == %@", "initial")
      request.propertiesToUpdate = ["display_name": "batch-updated"]
      request.resultType = .updatedObjectIDsResultType
      let result = try #require(background.execute(request) as? NSBatchUpdateResult)
      return try #require(result.result as? [NSManagedObjectID])
    }

    #expect(updatedIDs.contains(itemID))
    NSManagedObjectContext.mergeChanges(
      fromRemoteContextSave: [NSUpdatedObjectIDsKey: updatedIDs],
      into: [context]
    )
    context.processPendingChanges()

    #expect(routed.isEmpty == false)
    #expect(
      routed.allSatisfy { objectID, decision in
        objectID == itemID && decision == .allObservableKeyPaths
      }
    )
    #expect(domain.pendingObjectCount == 0)
    #expect(domain.pendingTokenCount == 0)
  }

  @MainActor
  @Test("batch delete object IDs route all-key fallback then unregister")
  func batchDeleteObjectIDsRouteAllKeyFallbackThenUnregister() async throws {
    guard #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *) else {
      return
    }

    let container = try makeContainer(
      testName: "ObservationRuntimeBatchDelete",
      automaticallyMergesChangesFromParent: false
    )
    let context = container.viewContext
    let item = try makeSavedItem(in: context, name: "initial")
    let itemID = item.objectID
    let background = container.newBackgroundContext()
    var routed: [(NSManagedObjectID, CDEObservationInvalidationDecision)] = []
    let domain = CDEObservationDomain(container: container) { object, decision in
      routed.append((object.objectID, decision))
    }

    _ = item.name
    _ = item.note
    let deletedIDs = try await background.perform {
      let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: "ObservationRuntimeItem")
      fetch.predicate = NSPredicate(format: "display_name == %@", "initial")
      let request = NSBatchDeleteRequest(fetchRequest: fetch)
      request.resultType = .resultTypeObjectIDs
      let result = try #require(background.execute(request) as? NSBatchDeleteResult)
      return try #require(result.result as? [NSManagedObjectID])
    }

    #expect(deletedIDs.contains(itemID))
    NSManagedObjectContext.mergeChanges(
      fromRemoteContextSave: [NSDeletedObjectIDsKey: deletedIDs],
      into: [context]
    )
    context.processPendingChanges()

    let routedChange = try #require(routed.first)
    #expect(routed.count == 1)
    #expect(routedChange.0 == itemID)
    #expect(routedChange.1 == .allObservableKeyPaths)
    #expect(domain.containsObservedObject(itemID) == false)
    #expect(domain.pendingObjectCount == 0)
    #expect(domain.pendingTokenCount == 0)
  }

  @MainActor
  @Test("merge routing is bounded by incoming object IDs")
  func mergeRoutingIsBoundedByIncomingObjectIDs() throws {
    guard #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *) else {
      return
    }

    let container = try makeContainer(testName: "ObservationRuntimeMergeRouting")
    let context = container.viewContext
    let observed = try makeSavedItem(in: context, name: "observed")
    let unobserved = try makeSavedItem(in: context, name: "unobserved")
    var routed: [(NSManagedObjectID, CDEObservationInvalidationDecision)] = []
    let domain = CDEObservationDomain(container: container) { object, decision in
      routed.append((object.objectID, decision))
    }
    let token = CDEObservationSaveToken()
    let nameSet = fieldSet(for: ["display_name"])
    let noteSet = fieldSet(for: ["note"])

    _ = observed.name
    _ = observed.note
    domain.stagePendingChange(token: token, objectID: observed.objectID, fieldSet: nameSet)
    domain.stagePendingChange(token: token, objectID: unobserved.objectID, fieldSet: noteSet)

    let plan = domain.routeMerge(affectedObjectIDs: [observed.objectID, unobserved.objectID])

    #expect(plan.lookupCount == 2)
    #expect(plan.decisionsByObjectID[observed.objectID] == .fieldSet(nameSet))
    #expect(plan.decisionsByObjectID[unobserved.objectID] == nil)
    #expect(routed.count == 1)
    #expect(routed.first?.0 == observed.objectID)
    #expect(domain.pendingObjectCount == 0)
    #expect(domain.pendingTokenCount == 0)
  }

  @MainActor
  @Test("background context getter read skips observed-object registration")
  func backgroundContextGetterReadSkipsObservedObjectRegistration() async throws {
    guard #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *) else {
      return
    }

    let container = try makeContainer(testName: "ObservationRuntimeBackgroundGetter")
    let context = container.viewContext
    let item = try makeSavedItem(in: context, name: "background")
    let objectID = item.objectID
    let background = container.newBackgroundContext()
    let domain = CDEObservationDomain(container: container)

    try await background.perform {
      let backgroundItem = try #require(
        try background.existingObject(with: objectID) as? ObservationRuntimeItem
      )
      #expect(backgroundItem.name == "background")
    }

    #expect(domain.liveObservedObjectIDs.isEmpty)

    _ = item.name
    _ = item.note
    #expect(domain.containsObservedObject(objectID))
  }

  @MainActor
  @Test("staged relationship field dispatches relationship and count")
  func stagedRelationshipFieldDispatchesRelationshipAndCount() throws {
    guard #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *) else {
      return
    }

    let container = try makeRelationshipContainer(
      testName: "ObservationRuntimeRelationshipDispatch"
    )
    let context = container.viewContext
    let parent = try makeSavedParent(in: context, name: "parent")
    let domain = CDEObservationDomain(container: container)
    let token = CDEObservationSaveToken()
    let childrenSet = ObservationRuntimeParent.__cdObservationFieldSet(
      forCoreDataKeys: ["children"]
    )
    let childrenCounter = ObservationChangeCounter()
    let countCounter = ObservationChangeCounter()
    let nameCounter = ObservationChangeCounter()

    _ = withObservationTracking {
      parent.children
    } onChange: {
      childrenCounter.increment()
    }
    _ = withObservationTracking {
      parent.childrenCount
    } onChange: {
      countCounter.increment()
    }
    _ = withObservationTracking {
      parent.name
    } onChange: {
      nameCounter.increment()
    }

    domain.stagePendingChange(token: token, objectID: parent.objectID, fieldSet: childrenSet)
    domain.routeMerge(affectedObjectIDs: [parent.objectID])

    #expect(childrenCounter.value == 1)
    #expect(countCounter.value == 1)
    #expect(nameCounter.value == 0)
  }

  @MainActor
  @Test("all-key dispatch is bounded to one observed object")
  func allKeyDispatchIsBoundedToOneObservedObject() throws {
    guard #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *) else {
      return
    }

    let container = try makeRelationshipContainer(testName: "ObservationRuntimeAllKeyDispatch")
    let context = container.viewContext
    let parent = try makeSavedParent(in: context, name: "parent")
    let child = try makeChild(in: context, name: "child")
    parent.addToChildren(child)
    try context.save()

    let domain = CDEObservationDomain(container: container)
    let nameCounter = ObservationChangeCounter()
    let childrenCounter = ObservationChangeCounter()
    let countCounter = ObservationChangeCounter()
    let childNameCounter = ObservationChangeCounter()

    _ = withObservationTracking {
      parent.name
    } onChange: {
      nameCounter.increment()
    }
    _ = withObservationTracking {
      parent.children
    } onChange: {
      childrenCounter.increment()
    }
    _ = withObservationTracking {
      parent.childrenCount
    } onChange: {
      countCounter.increment()
    }
    _ = withObservationTracking {
      child.name
    } onChange: {
      childNameCounter.increment()
    }

    domain.routeAllKeyFallback(affectedObjectIDs: [parent.objectID])

    #expect(nameCounter.value == 1)
    #expect(childrenCounter.value == 1)
    #expect(countCounter.value == 1)
    #expect(childNameCounter.value == 0)
  }

  @MainActor
  @Test("pending buffer merges consumes rolls back scopes and compresses")
  func pendingBufferMergesConsumesRollsBackScopesAndCompresses() throws {
    guard #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *) else {
      return
    }

    let container = try makeContainer(testName: "ObservationRuntimePendingBuffer")
    let context = container.viewContext
    let item = try makeSavedItem(in: context, name: "buffered")
    let objectID = item.objectID
    let nameSet = fieldSet(for: ["display_name"])
    let noteSet = fieldSet(for: ["note"])
    let firstToken = CDEObservationSaveToken()
    let secondToken = CDEObservationSaveToken()
    let buffer = CDEObservationPendingBuffer()

    buffer.register(token: firstToken, objectID: objectID, fieldSet: nameSet)
    buffer.register(token: secondToken, objectID: objectID, fieldSet: noteSet)

    #expect(buffer.pendingChange(for: objectID) == .fieldSet(nameSet.union(noteSet)))
    #expect(buffer.pendingObjectCount == 1)
    #expect(buffer.tokenCount == 2)

    buffer.rollback(token: secondToken)

    #expect(buffer.pendingChange(for: objectID) == .fieldSet(nameSet))
    #expect(buffer.tokenCount == 1)
    #expect(buffer.consume(objectID: objectID) == .fieldSet(nameSet))
    #expect(buffer.pendingObjectCount == 0)
    #expect(buffer.tokenCount == 0)

    let failedToken = CDEObservationSaveToken()
    buffer.register(token: failedToken, objectID: objectID, fieldSet: nameSet)
    buffer.rollback(token: failedToken)
    #expect(buffer.pendingChange(for: objectID) == nil)

    let scopedA = CDEObservationPendingBuffer()
    let scopedB = CDEObservationPendingBuffer()
    let scopedToken = CDEObservationSaveToken()
    scopedA.register(token: scopedToken, objectID: objectID, fieldSet: nameSet)
    #expect(scopedA.pendingChange(for: objectID) == .fieldSet(nameSet))
    #expect(scopedB.pendingChange(for: objectID) == nil)

    let compressedToken = CDEObservationSaveToken()
    buffer.register(token: compressedToken, objectID: objectID, fieldSet: nameSet)
    buffer.compress(objectID: objectID)
    #expect(buffer.pendingChange(for: objectID) == .allObservableKeyPaths)
    #expect(buffer.consume(objectID: objectID) == .allObservableKeyPaths)
  }

  @MainActor
  @Test("weak observed table rekeys prunes deletes and resets")
  func weakObservedTableRekeysPrunesDeletesAndResets() throws {
    guard #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *) else {
      return
    }

    let container = try makeContainer(testName: "ObservationRuntimeWeakTable")
    let context = container.viewContext
    let item = try makeUnsavedItem(in: context, name: "temporary")
    let table = CDEObservationObjectIDTable()
    let temporaryID = item.objectID

    #expect(temporaryID.isTemporaryID)
    table.register(item)
    #expect(table.contains(temporaryID))

    try context.obtainPermanentIDs(for: [item])
    table.rekey(item, from: temporaryID)

    #expect(table.contains(temporaryID) == false)
    #expect(table.contains(item.objectID))

    table.unregister(item.objectID)
    #expect(table.contains(item.objectID) == false)

    table.register(item)
    table.removeAll()
    #expect(table.liveObjectIDs.isEmpty)
  }

  @MainActor
  private func makeRelationshipContainer(testName: String) throws -> NSPersistentContainer {
    let container = try NSPersistentContainer.makeRuntimeTest(
      modelTypes: [ObservationRuntimeParent.self, ObservationRuntimeChild.self],
      testName: testName
    )
    container.viewContext.automaticallyMergesChangesFromParent = true
    return container
  }

  @MainActor
  private func makeContainer(
    testName: String,
    automaticallyMergesChangesFromParent: Bool = true
  ) throws -> NSPersistentContainer {
    let container = try NSPersistentContainer.makeRuntimeTest(
      modelTypes: [ObservationRuntimeItem.self],
      testName: testName
    )
    container.viewContext.automaticallyMergesChangesFromParent =
      automaticallyMergesChangesFromParent
    return container
  }

  @MainActor
  private func makeSavedItem(
    in context: NSManagedObjectContext,
    name: String
  ) throws -> ObservationRuntimeItem {
    let item = try makeUnsavedItem(in: context, name: name)
    try context.save()
    return item
  }

  @MainActor
  private func makeUnsavedItem(
    in context: NSManagedObjectContext,
    name: String
  ) throws -> ObservationRuntimeItem {
    let entity = try #require(
      NSEntityDescription.entity(forEntityName: "ObservationRuntimeItem", in: context)
    )
    let item = ObservationRuntimeItem(entity: entity, insertInto: context)
    item.name = name
    item.note = "note"
    return item
  }

  @MainActor
  private func makeSavedParent(
    in context: NSManagedObjectContext,
    name: String
  ) throws -> ObservationRuntimeParent {
    let parent = try makeParent(in: context, name: name)
    try context.save()
    return parent
  }

  @MainActor
  private func makeParent(
    in context: NSManagedObjectContext,
    name: String
  ) throws -> ObservationRuntimeParent {
    let entity = try #require(
      NSEntityDescription.entity(forEntityName: "ObservationRuntimeParent", in: context)
    )
    let parent = ObservationRuntimeParent(entity: entity, insertInto: context)
    parent.name = name
    return parent
  }

  @MainActor
  private func makeChild(
    in context: NSManagedObjectContext,
    name: String
  ) throws -> ObservationRuntimeChild {
    let entity = try #require(
      NSEntityDescription.entity(forEntityName: "ObservationRuntimeChild", in: context)
    )
    let child = ObservationRuntimeChild(entity: entity, insertInto: context)
    child.name = name
    return child
  }

  private func fieldSet(for coreDataKeys: [String]) -> CDEObservationFieldSet {
    ObservationRuntimeItem.__cdObservationFieldSet(forCoreDataKeys: coreDataKeys)
  }

  private func paths(for decision: CDEObservationInvalidationDecision) -> [String] {
    switch decision {
    case .fieldSet(let fieldSet):
      return ObservationRuntimeItem.__cdObservationSwiftPaths(for: fieldSet)
    case .allObservableKeyPaths:
      return ["*"]
    }
  }

  private func readItemNote(
    container: NSPersistentContainer,
    id: NSManagedObjectID
  ) async throws -> String? {
    let context = container.newBackgroundContext()
    return try await context.perform {
      try (context.existingObject(with: id) as? ObservationRuntimeItem)?.note
    }
  }

  @MainActor
  private func waitForCondition(_ condition: () -> Bool) async {
    for _ in 0..<50 {
      if condition() {
        return
      }
      try? await Task.sleep(nanoseconds: 20_000_000)
    }
  }

  /// Yields the main run loop long enough for several `kCFRunLoopBeforeWaiting` drains to fire,
  /// modeling the run-loop sleep between a local `viewContext` save and its cross-cycle echo.
  private func drainRunLoopForEchoWindow() async {
    try? await Task.sleep(nanoseconds: 60_000_000)
  }

  private func waitSynchronously(
    for semaphore: DispatchSemaphore,
    timeout: DispatchTime
  ) -> DispatchTimeoutResult {
    semaphore.wait(timeout: timeout)
  }
}

@MainActor
private func blockMainActor(
  entered: DispatchSemaphore,
  release: DispatchSemaphore
) {
  entered.signal()
  _ = release.wait(timeout: .distantFuture)
}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
private final class ObservationActorSaveOrderingFixture: @unchecked Sendable {
  let container: NSPersistentContainer
  let itemID: NSManagedObjectID
  let actor: ObservationRuntimeMetadataActor
  private let lock = NSLock()
  private var domainStorage: CDEObservationDomain?

  var domain: CDEObservationDomain {
    lock.withLock {
      precondition(domainStorage != nil)
      return domainStorage!
    }
  }

  init(
    container: NSPersistentContainer,
    itemID: NSManagedObjectID,
    actor: ObservationRuntimeMetadataActor,
    domain: CDEObservationDomain
  ) {
    self.container = container
    self.itemID = itemID
    self.actor = actor
    domainStorage = domain
  }

  @MainActor
  func releaseDomain() {
    let domain = lock.withLock {
      defer {
        domainStorage = nil
      }
      return domainStorage
    }
    domain?.invalidate()
  }
}

// `withObservationTracking` captures `onChange` in a sendable closure.
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

private final class ObservationNotificationRecorder: @unchecked Sendable {
  private let lock = NSLock()
  private var token: NSObjectProtocol?
  private var storage: Notification?

  var lastNotification: Notification? {
    lock.withLock { storage }
  }

  init(context: NSManagedObjectContext, name: Notification.Name) {
    token = NotificationCenter.default.addObserver(
      forName: name,
      object: context,
      queue: nil
    ) { [weak self] notification in
      guard let self else {
        return
      }

      self.lock.withLock {
        self.storage = notification
      }
    }
  }

  deinit {
    if let token {
      NotificationCenter.default.removeObserver(token)
    }
  }
}
