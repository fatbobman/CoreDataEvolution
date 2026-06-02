import CoreDataEvolution
public actor SnapshotModelActor {

  public nonisolated let modelExecutor: CoreDataEvolution.NSModelObjectContextExecutor

  public nonisolated let modelContainer: CoreData.NSPersistentContainer

  #if compiler(>=6.2)
  private nonisolated(unsafe) let __cdeObservationDomain: AnyObject?

  private nonisolated(unsafe) let __cdeObservationProducerRegistration: AnyObject?

  deinit {
    let registration =
      __cdeObservationProducerRegistration as? CoreDataEvolution.CDEObservationProducerRegistration
    registration?.invalidate()
  }
  #endif

  public init(container: CoreData.NSPersistentContainer) {
    let context: NSManagedObjectContext
    context = container.newBackgroundContext()
    #if compiler(>=6.2)
    __cdeObservationDomain = nil
    __cdeObservationProducerRegistration = nil
    #endif
    modelExecutor = CoreDataEvolution.NSModelObjectContextExecutor(context: context)
    modelContainer = container
  }

  #if compiler(>=6.2)
  @MainActor
  @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
  public init(observationDomain: CoreDataEvolution.CDEObservationDomain) {
    let container: CoreData.NSPersistentContainer
    container = observationDomain.modelContainer
    let context: NSManagedObjectContext
    context = container.newBackgroundContext()
    __cdeObservationDomain = observationDomain
    __cdeObservationProducerRegistration =
      observationDomain.registerChangeProducer(context: context)
    modelExecutor = CoreDataEvolution.NSModelObjectContextExecutor(context: context)
    modelContainer = container
  }
  #endif

  #if compiler(>=6.2)
  @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
  public func saveObservedChanges() async throws {
    guard __cdeObservationDomain != nil else {
      CoreDataEvolution._cdeLogUnboundModelActorObservationSave()
      try modelContext.save()
      return
    }
    do {
      try modelContext.save()
    } catch {
      modelContext.rollback()
      throw error
    }
  }
  #endif
}

extension SnapshotModelActor: CoreDataEvolution.NSModelActor {
}