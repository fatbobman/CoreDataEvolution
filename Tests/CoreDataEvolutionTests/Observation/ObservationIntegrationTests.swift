#if compiler(>=6.2)
  @preconcurrency import CoreData
  import Foundation
  import Observation
  import Testing

  @testable import CoreDataEvolution

  @objc(ObservationIntegrationRoot)
  @PersistentModel(observation: .mainActor)
  final class ObservationIntegrationRoot: NSManagedObject {
    var title: String = ""
    var summary: String = ""

    @Relationship(inverse: "root", deleteRule: .nullify)
    var child: ObservationIntegrationChild?

    @Relationship(inverse: "root", deleteRule: .nullify)
    var orders: Set<ObservationIntegrationOrder>
  }

  @objc(ObservationIntegrationChild)
  @PersistentModel(observation: .mainActor)
  final class ObservationIntegrationChild: NSManagedObject {
    var name: String = ""

    @Relationship(inverse: "child", deleteRule: .nullify)
    var root: ObservationIntegrationRoot?

    @Relationship(inverse: "child", deleteRule: .nullify)
    var leaf: ObservationIntegrationLeaf?
  }

  @objc(ObservationIntegrationLeaf)
  @PersistentModel(observation: .mainActor)
  final class ObservationIntegrationLeaf: NSManagedObject {
    var name: String = ""
    var note: String = ""

    @Relationship(inverse: "leaf", deleteRule: .nullify)
    var child: ObservationIntegrationChild?
  }

  @objc(ObservationIntegrationOrder)
  @PersistentModel(observation: .mainActor)
  final class ObservationIntegrationOrder: NSManagedObject {
    var label: String = ""

    @Relationship(inverse: "orders", deleteRule: .nullify)
    var root: ObservationIntegrationRoot?
  }

  @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
  @NSModelActor(disableGenerateInit: true)
  private actor ObservationIntegrationWriter {
    init(container: NSPersistentContainer) {
      modelContainer = container
      let context = container.newBackgroundContext()
      context.name = "ObservationIntegrationWriter"
      modelExecutor = .init(context: context)
    }

    func updateRootTitle(
      id: NSManagedObjectID,
      newTitle: String,
      in domain: CDEObservationDomain
    ) async throws {
      let root = try requireRoot(id: id)
      root.title = newTitle
      try await saveObservedChanges(in: domain)
    }

    func updateRootSummary(
      id: NSManagedObjectID,
      newSummary: String,
      in domain: CDEObservationDomain
    ) async throws {
      let root = try requireRoot(id: id)
      root.summary = newSummary
      try await saveObservedChanges(in: domain)
    }

    func updateLeafName(
      id: NSManagedObjectID,
      newName: String,
      in domain: CDEObservationDomain
    ) async throws {
      let leaf = try requireLeaf(id: id)
      leaf.name = newName
      try await saveObservedChanges(in: domain)
    }

    func updateLeafNote(
      id: NSManagedObjectID,
      newNote: String,
      in domain: CDEObservationDomain
    ) async throws {
      let leaf = try requireLeaf(id: id)
      leaf.note = newNote
      try await saveObservedChanges(in: domain)
    }

    func updateLeafNameWithDirectSave(
      id: NSManagedObjectID,
      newName: String
    ) throws {
      let leaf = try requireLeaf(id: id)
      leaf.name = newName
      try modelContext.save()
    }

    func insertOrder(
      rootID: NSManagedObjectID,
      label: String,
      in domain: CDEObservationDomain
    ) async throws -> NSManagedObjectID {
      let root = try requireRoot(id: rootID)
      let entity = try #require(
        NSEntityDescription.entity(forEntityName: "ObservationIntegrationOrder", in: modelContext)
      )
      let order = ObservationIntegrationOrder(entity: entity, insertInto: modelContext)
      order.label = label
      order.root = root
      try await saveObservedChanges(in: domain)
      return order.objectID
    }

    private func requireRoot(id: NSManagedObjectID) throws -> ObservationIntegrationRoot {
      try #require(
        try modelContext.existingObject(with: id) as? ObservationIntegrationRoot
      )
    }

    private func requireLeaf(id: NSManagedObjectID) throws -> ObservationIntegrationLeaf {
      try #require(
        try modelContext.existingObject(with: id) as? ObservationIntegrationLeaf
      )
    }
  }

  @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
  @NSModelActor
  private actor ObservationGeneratedWriter {
    func updateRootTitleWithDirectSave(
      id: NSManagedObjectID,
      newTitle: String
    ) throws {
      let root = try requireRoot(id: id)
      root.title = newTitle
      try modelContext.save()
    }

    func updateRootTitleWithStoredObservedSave(
      id: NSManagedObjectID,
      newTitle: String
    ) async throws {
      let root = try requireRoot(id: id)
      root.title = newTitle
      try await saveObservedChanges()
    }

    func updateRootSummaryWithDirectSave(
      id: NSManagedObjectID,
      newSummary: String
    ) throws {
      let root = try requireRoot(id: id)
      root.summary = newSummary
      try modelContext.save()
    }

    func updateRootSummaryWithStoredObservedSave(
      id: NSManagedObjectID,
      newSummary: String
    ) async throws {
      let root = try requireRoot(id: id)
      root.summary = newSummary
      try await saveObservedChanges()
    }

    private func requireRoot(id: NSManagedObjectID) throws -> ObservationIntegrationRoot {
      try #require(
        try modelContext.existingObject(with: id) as? ObservationIntegrationRoot
      )
    }
  }

  @Suite("Observation Integration", .serialized)
  struct ObservationIntegrationTests {
    @MainActor
    @Test("observed background save invalidates tracked property only")
    func observedBackgroundSaveInvalidatesTrackedPropertyOnly() async throws {
      guard #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *) else {
        return
      }

      let container = try makeContainer(testName: "ObservationIntegrationPreciseAttribute")
      let context = container.viewContext
      let graph = try makeSavedGraph(in: context)
      let writer = ObservationIntegrationWriter(container: container)
      let domain = CDEObservationDomain(container: container)
      let titleCounter = ObservationIntegrationChangeCounter()

      _ = withObservationTracking {
        graph.root.title
      } onChange: {
        titleCounter.increment()
      }

      try await writer.updateRootSummary(
        id: graph.root.objectID,
        newSummary: "summary-changed",
        in: domain
      )
      await waitForCondition { graph.root.summary == "summary-changed" }

      #expect(graph.root.summary == "summary-changed")
      #expect(titleCounter.value == 0)

      try await writer.updateRootTitle(
        id: graph.root.objectID,
        newTitle: "title-changed",
        in: domain
      )
      await waitForCondition { titleCounter.value == 1 }

      #expect(graph.root.title == "title-changed")
      #expect(titleCounter.value == 1)
    }

    @MainActor
    @Test("deep relationship read refreshes only when the leaf field changes")
    func deepRelationshipReadRefreshesOnlyWhenTheLeafFieldChanges() async throws {
      guard #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *) else {
        return
      }

      let container = try makeContainer(testName: "ObservationIntegrationDeepRelationship")
      let context = container.viewContext
      let graph = try makeSavedGraph(in: context)
      let writer = ObservationIntegrationWriter(container: container)
      let domain = CDEObservationDomain(container: container)
      let leafNameCounter = ObservationIntegrationChangeCounter()

      _ = withObservationTracking {
        graph.root.child?.leaf?.name
      } onChange: {
        leafNameCounter.increment()
      }

      try await writer.updateLeafNote(
        id: graph.leaf.objectID,
        newNote: "leaf-note-changed",
        in: domain
      )
      await waitForCondition { graph.root.child?.leaf?.note == "leaf-note-changed" }

      #expect(graph.root.child?.leaf?.note == "leaf-note-changed")
      #expect(leafNameCounter.value == 0)

      try await writer.updateLeafName(
        id: graph.leaf.objectID,
        newName: "leaf-name-changed",
        in: domain
      )
      await waitForCondition { leafNameCounter.value == 1 }

      #expect(graph.root.child?.leaf?.name == "leaf-name-changed")
      #expect(leafNameCounter.value == 1)
    }

    @MainActor
    @Test("to-many count reader refreshes when a related object is inserted")
    func toManyCountReaderRefreshesWhenRelatedObjectIsInserted() async throws {
      guard #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *) else {
        return
      }

      let container = try makeContainer(testName: "ObservationIntegrationCountFanout")
      let context = container.viewContext
      let graph = try makeSavedGraph(in: context)
      let writer = ObservationIntegrationWriter(container: container)
      let domain = CDEObservationDomain(container: container)
      let countCounter = ObservationIntegrationChangeCounter()

      #expect(graph.root.ordersCount == 0)
      _ = withObservationTracking {
        graph.root.ordersCount
      } onChange: {
        countCounter.increment()
      }

      let orderID = try await writer.insertOrder(
        rootID: graph.root.objectID,
        label: "first-order",
        in: domain
      )
      await waitForCondition {
        countCounter.value == 1 && graph.root.ordersCount == 1
      }

      #expect(orderID.isTemporaryID == false)
      #expect(graph.root.ordersCount == 1)
      #expect(countCounter.value == 1)
    }

    @MainActor
    @Test("generated observed actor initializer supports precise direct save")
    func generatedObservedActorInitializerSupportsPreciseDirectSave() async throws {
      guard #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *) else {
        return
      }

      let container = try makeContainer(testName: "ObservationGeneratedActorDirectSave")
      let context = container.viewContext
      let graph = try makeSavedGraph(in: context)
      let writer = ObservationGeneratedWriter(
        observationDomain: CDEObservationDomain(container: container)
      )
      let titleCounter = ObservationIntegrationChangeCounter()

      _ = withObservationTracking {
        graph.root.title
      } onChange: {
        titleCounter.increment()
      }

      try await writer.updateRootSummaryWithDirectSave(
        id: graph.root.objectID,
        newSummary: "generated-summary-changed"
      )
      await waitForCondition { graph.root.summary == "generated-summary-changed" }

      #expect(graph.root.summary == "generated-summary-changed")
      #expect(titleCounter.value == 0)

      try await writer.updateRootTitleWithStoredObservedSave(
        id: graph.root.objectID,
        newTitle: "generated-title-changed"
      )
      await waitForCondition { titleCounter.value == 1 }

      #expect(graph.root.title == "generated-title-changed")
      #expect(titleCounter.value == 1)
    }

    @MainActor
    @Test("generated observed actor releases its producer registration")
    func generatedObservedActorReleasesItsProducerRegistration() async throws {
      guard #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *) else {
        return
      }

      let container = try makeContainer(testName: "ObservationGeneratedActorRegistrationRelease")
      let domain = CDEObservationDomain(container: container)
      do {
        let writer = ObservationGeneratedWriter(observationDomain: domain)
        #expect(domain.producerRegistrationCount == 1)
        withExtendedLifetime(writer) {}
      }

      await waitForCondition { domain.producerRegistrationCount == 0 }
      #expect(domain.producerRegistrationCount == 0)
    }

    @MainActor
    @Test("generated saveObservedChanges fallback uses a plain unregistered save")
    func generatedObservedSaveFallbackUsesPlainUnregisteredSave() async throws {
      guard #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *) else {
        return
      }

      let container = try makeContainer(testName: "ObservationGeneratedActorFallbackSave")
      let context = container.viewContext
      let graph = try makeSavedGraph(in: context)
      let domain = CDEObservationDomain(container: container)
      let writer = ObservationGeneratedWriter(container: container)
      let titleCounter = ObservationIntegrationChangeCounter()

      _ = withObservationTracking {
        graph.root.title
      } onChange: {
        titleCounter.increment()
      }

      try await writer.updateRootSummaryWithStoredObservedSave(
        id: graph.root.objectID,
        newSummary: "fallback-summary-changed"
      )
      await waitForCondition {
        graph.root.summary == "fallback-summary-changed" && titleCounter.value == 1
      }

      #expect(graph.root.summary == "fallback-summary-changed")
      #expect(titleCounter.value == 1)
      #expect(domain.pendingObjectCount == 0)
      #expect(domain.producerRegistrationCount == 0)
    }

    // P0 regression guard (issue #16): inline construction makes the generated actor the sole strong
    // owner of `CDEObservationDomain`. Releasing that actor off the MainActor used to trap in the
    // domain's deinit; this subprocess must now exit cleanly.
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
    @Test("off-main release of an inline observation domain exits cleanly")
    func offMainReleaseOfRetainedObservationDomainExitsCleanly() async {
      await #expect(processExitsWith: .success) {
        // The subprocess builds the container + inline domain + observed actor on the MainActor, then
        // hands the sole reference to a detached (background) executor and releases it there.
        await Task.detached {
          let writer: ObservationGeneratedWriter
          do {
            writer = try await MainActor.run {
              let container = try NSPersistentContainer.makeRuntimeTest(
                modelTypes: ObservationIntegrationRoot.self,
                ObservationIntegrationChild.self,
                ObservationIntegrationLeaf.self,
                ObservationIntegrationOrder.self,
                testName: "P0OffMainObservedActorRelease"
              )
              return ObservationGeneratedWriter(
                observationDomain: CDEObservationDomain(container: container)
              )
            }
          } catch {
            // Unrelated setup failure must fail the `.success` expectation instead of masquerading as
            // a clean off-main teardown.
            exit(EXIT_FAILURE)
          }
          // Releasing `writer` here runs the actor's deinit — and therefore the solely-owned
          // CDEObservationDomain's deinit — off the MainActor.
          withExtendedLifetime(writer) {}
        }.value
        exit(EXIT_SUCCESS)
      }
    }

    @MainActor
    @Test("objectID fallback still refreshes a deep relationship reader")
    func objectIDFallbackStillRefreshesADeepRelationshipReader() async throws {
      guard #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *) else {
        return
      }

      let container = try makeContainer(testName: "ObservationIntegrationFallbackDeepRead")
      let context = container.viewContext
      let graph = try makeSavedGraph(in: context)
      let writer = ObservationIntegrationWriter(container: container)
      let domain = CDEObservationDomain(container: container)
      let leafNameCounter = ObservationIntegrationChangeCounter()

      _ = withObservationTracking {
        graph.root.child?.leaf?.name
      } onChange: {
        leafNameCounter.increment()
      }

      try await writer.updateLeafNameWithDirectSave(
        id: graph.leaf.objectID,
        newName: "fallback-leaf-name"
      )
      await waitForCondition { leafNameCounter.value == 1 }

      #expect(graph.root.child?.leaf?.name == "fallback-leaf-name")
      #expect(leafNameCounter.value == 1)
      #expect(domain.pendingObjectCount == 0)
    }

    @MainActor
    private func makeContainer(testName: String) throws -> NSPersistentContainer {
      let container = try NSPersistentContainer.makeRuntimeTest(
        modelTypes: [
          ObservationIntegrationRoot.self,
          ObservationIntegrationChild.self,
          ObservationIntegrationLeaf.self,
          ObservationIntegrationOrder.self,
        ],
        testName: testName
      )
      container.viewContext.automaticallyMergesChangesFromParent = true
      return container
    }

    @MainActor
    private func makeSavedGraph(
      in context: NSManagedObjectContext
    ) throws -> ObservationIntegrationGraph {
      let rootEntity = try #require(
        NSEntityDescription.entity(forEntityName: "ObservationIntegrationRoot", in: context)
      )
      let childEntity = try #require(
        NSEntityDescription.entity(forEntityName: "ObservationIntegrationChild", in: context)
      )
      let leafEntity = try #require(
        NSEntityDescription.entity(forEntityName: "ObservationIntegrationLeaf", in: context)
      )

      let root = ObservationIntegrationRoot(entity: rootEntity, insertInto: context)
      root.title = "root-title"
      root.summary = "root-summary"

      let child = ObservationIntegrationChild(entity: childEntity, insertInto: context)
      child.name = "child-name"
      child.root = root

      let leaf = ObservationIntegrationLeaf(entity: leafEntity, insertInto: context)
      leaf.name = "leaf-name"
      leaf.note = "leaf-note"
      leaf.child = child

      try context.save()
      return ObservationIntegrationGraph(root: root, child: child, leaf: leaf)
    }

    @MainActor
    private func waitForCondition(_ condition: () -> Bool) async {
      for _ in 0..<100 {
        if condition() {
          return
        }
        try? await Task.sleep(nanoseconds: 20_000_000)
      }
    }
  }

  private struct ObservationIntegrationGraph {
    let root: ObservationIntegrationRoot
    let child: ObservationIntegrationChild
    let leaf: ObservationIntegrationLeaf
  }

  // `withObservationTracking` captures `onChange` in a sendable closure.
  private final class ObservationIntegrationChangeCounter: @unchecked Sendable {
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

#endif
