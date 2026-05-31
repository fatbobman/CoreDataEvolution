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

@Suite("Observation Runtime Core")
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

  @MainActor
  @Test("background actor observed save does not suspend between staging and save")
  func backgroundActorObservedSaveDoesNotSuspendBetweenStagingAndSave() async throws {
    guard #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *) else {
      return
    }

    let container = try makeContainer(testName: "ObservationRuntimeActorObservedSaveOrdering")
    let context = container.viewContext
    let item = try makeSavedItem(in: context, name: "initial")
    let itemID = item.objectID
    let actor = ObservationRuntimeMetadataActor(container: container)
    let prepared = DispatchSemaphore(value: 0)
    let reentrantDone = DispatchSemaphore(value: 0)
    var routed: [(NSManagedObjectID, CDEObservationInvalidationDecision)] = []
    let domain = CDEObservationDomain(container: container) { object, decision in
      routed.append((object.objectID, decision))
    }

    _ = item.name
    _ = item.note

    let saveTask = Task.detached {
      try await actor.updateItemNameAfterSignal(
        id: itemID,
        newName: "actor-observed",
        in: domain
      ) {
        prepared.signal()
      }
    }
    #expect(waitSynchronously(for: prepared, timeout: .now() + 5) == .success)

    // Keep MainActor occupied so the old async MainActor staging hop would suspend the actor save.
    // A reentrant actor job then mutates the same context before the old implementation could save.
    let reentrantTask = Task.detached {
      try await actor.updateItemNoteWithoutSave(
        id: itemID,
        newNote: "reentrant-note"
      )
      reentrantDone.signal()
    }
    #expect(waitSynchronously(for: reentrantDone, timeout: .now() + 5) == .success)

    try await saveTask.value
    try await reentrantTask.value
    await waitForCondition { routed.isEmpty == false }

    let routedChange = try #require(routed.first)
    let persistedNote = try await readItemNote(container: container, id: itemID)
    #expect(routed.count == 1)
    #expect(paths(for: routedChange.1) == ["name"])
    #expect(persistedNote == "note")
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
  private func makeContainer(testName: String) throws -> NSPersistentContainer {
    let container = try NSPersistentContainer.makeRuntimeTest(
      modelTypes: [ObservationRuntimeItem.self],
      testName: testName
    )
    container.viewContext.automaticallyMergesChangesFromParent = true
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

  private func waitSynchronously(
    for semaphore: DispatchSemaphore,
    timeout: DispatchTime
  ) -> DispatchTimeoutResult {
    semaphore.wait(timeout: timeout)
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
