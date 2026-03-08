@preconcurrency import CoreData
import CoreDataEvolution
import Foundation
import GeneratedModels

@main
struct GeneratedQuantifierApp {
  static func main() throws {
    FlowStringListTransformer.register()
    let modelURL = try FixtureSupport.compileModel()
    let container = try FixtureSupport.makeContainer(modelURL: modelURL)
    try seed(in: container.viewContext)
    container.viewContext.reset()
    let summary = try fetchAndAssert(in: container.viewContext)
    print(summary)
  }

  private static func seed(in context: NSManagedObjectContext) throws {
    let schemaLab = FlowProject(context: context)
    schemaLab.id = UUID()
    schemaLab.name = "Schema Lab"

    let migrationDesk = FlowProject(context: context)
    migrationDesk.id = UUID()
    migrationDesk.name = "Migration Desk"

    let reviewTask = FlowTask(context: context)
    reviewTask.id = UUID()
    reviewTask.title = "Review generated flow"
    reviewTask.createdAt = Date(timeIntervalSince1970: 1_700_000_100)
    reviewTask.status = .review
    reviewTask.config = .init(owner: "fatbobman", retryCount: 2, isFlagged: true)
    reviewTask.tags = ["generated", "quantifier"]
    reviewTask.location = .init(latitude: 31.2304, longitude: 121.4737)
    reviewTask.project = schemaLab

    let mappingTask = FlowTask(context: context)
    mappingTask.id = UUID()
    mappingTask.title = "Map composition leaf"
    mappingTask.createdAt = Date(timeIntervalSince1970: 1_700_000_200)
    mappingTask.status = .done
    mappingTask.config = .init(owner: "yangxu", retryCount: 1, isFlagged: false)
    mappingTask.tags = nil
    mappingTask.location = .init(latitude: 30.2741, longitude: 120.1551)
    mappingTask.project = schemaLab

    let legacyTask = FlowTask(context: context)
    legacyTask.id = UUID()
    legacyTask.title = "Legacy cleanup"
    legacyTask.createdAt = Date(timeIntervalSince1970: 1_700_000_300)
    legacyTask.status = .backlog
    legacyTask.config = .init(owner: "sam", retryCount: 0, isFlagged: false)
    legacyTask.tags = ["legacy"]
    legacyTask.location = .init(latitude: 22.5431, longitude: 114.0579)
    legacyTask.project = migrationDesk

    try context.save()
  }

  private static func fetchAndAssert(in context: NSManagedObjectContext) throws -> String {
    let anyGeneratedRequest = NSFetchRequest<FlowProject>(entityName: "FlowProject")
    anyGeneratedRequest.sortDescriptors = [
      try NSSortDescriptor(FlowProject.self, path: FlowProject.path.name, order: .asc)
    ]
    anyGeneratedRequest.predicate = FlowProject.path.tasks.any.title.contains("generated")

    let anyGeneratedProjects = try context.fetch(anyGeneratedRequest)
    try assert(
      anyGeneratedProjects.map(\.name) == ["Schema Lab"],
      "Expected only Schema Lab to match tasks.any.title.contains(\"generated\").")

    let noLegacyRequest = NSFetchRequest<FlowProject>(entityName: "FlowProject")
    noLegacyRequest.sortDescriptors = [
      try NSSortDescriptor(FlowProject.self, path: FlowProject.path.name, order: .asc)
    ]
    noLegacyRequest.predicate = FlowProject.path.tasks.none.title.contains("Legacy")

    let noLegacyProjects = try context.fetch(noLegacyRequest)
    try assert(
      noLegacyProjects.map(\.name) == ["Schema Lab"],
      "Expected only Schema Lab to match tasks.none.title.contains(\"Legacy\").")

    let nilTagsRequest = NSFetchRequest<FlowTask>(entityName: "FlowTask")
    nilTagsRequest.sortDescriptors = [
      try NSSortDescriptor(FlowTask.self, path: FlowTask.path.title, order: .asc)
    ]
    nilTagsRequest.predicate = FlowTask.path.project.name.equals("Schema Lab")

    let schemaLabTasks = try context.fetch(nilTagsRequest)
    try assert(schemaLabTasks.count == 2, "Expected exactly two tasks for Schema Lab.")
    let nilTagTask = schemaLabTasks.first(where: { $0.title == "Map composition leaf" })
    try assert(
      nilTagTask?.tags == nil, "Expected nil tags to round-trip for \"Map composition leaf\".")

    return
      "any=\(anyGeneratedProjects.map(\.name).joined(separator: ",")) | none=\(noLegacyProjects.map(\.name).joined(separator: ",")) | nilTags=\(nilTagTask?.title ?? "missing")"
  }

  private static func assert(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    guard condition() else {
      throw NSError(
        domain: "GeneratedQuantifierApp",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: message]
      )
    }
  }
}
