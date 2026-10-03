@preconcurrency import CoreDataEvolution

// No availability annotation: the default initializer must support older deployment targets.
@NSModelActor
actor ModelActorAvailabilityHandler {
  func usesBackgroundContext() -> Bool {
    modelContext.concurrencyType == .privateQueueConcurrencyType
  }
}

@main
struct ModelActorAvailabilityApp {
  static func main() async {
    let container = NSPersistentContainer(
      name: "ModelActorAvailability", managedObjectModel: NSManagedObjectModel())
    let handler = ModelActorAvailabilityHandler(container: container)
    let usesBackgroundContext = await handler.usesBackgroundContext()
    precondition(usesBackgroundContext)
    print("Default model actor availability flow passed")
  }
}
