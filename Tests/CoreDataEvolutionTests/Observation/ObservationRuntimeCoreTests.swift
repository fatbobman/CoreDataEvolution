@preconcurrency import CoreData
import Testing

@testable import CoreDataEvolution

@objc(ObservationRuntimeItem)
@PersistentModel(observation: .mainActor)
final class ObservationRuntimeItem: NSManagedObject {
  @Attribute(persistentName: "display_name")
  var name: String = ""

  var note: String = ""
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
}
