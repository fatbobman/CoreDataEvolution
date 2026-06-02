import CoreDataEvolution
public actor SnapshotManualModelActor {
  public init(
    modelExecutor: CoreDataEvolution.NSModelObjectContextExecutor,
    modelContainer: NSPersistentContainer
  ) {
    self.modelExecutor = modelExecutor
    self.modelContainer = modelContainer
  }

  public nonisolated let modelExecutor: CoreDataEvolution.NSModelObjectContextExecutor

  public nonisolated let modelContainer: CoreData.NSPersistentContainer
}

extension SnapshotManualModelActor: CoreDataEvolution.NSModelActor {
}