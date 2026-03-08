@preconcurrency import CoreData
import CoreDataEvolution
import Foundation
import GeneratedModels

@main
struct GeneratedFlowApp {
  static func main() throws {
    FlowStringListTransformer.register()
    let modelURL = try compileModel()
    let container = try makeContainer(modelURL: modelURL)
    try seed(in: container.viewContext)
    container.viewContext.reset()
    let summary = try fetchAndAssert(in: container.viewContext)
    print(summary)
  }

  private static func compileModel() throws -> URL {
    let fileURL = URL(fileURLWithPath: #filePath)
    let packageRoot =
      fileURL
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let modelSource =
      packageRoot
      .appendingPathComponent("Models")
      .appendingPathComponent("GeneratedFlowModel.xcdatamodeld")
    let outputDirectory =
      packageRoot
      .appendingPathComponent(".build")
      .appendingPathComponent("generated-flow-models", isDirectory: true)
    let outputURL = outputDirectory.appendingPathComponent("GeneratedFlowModel.momd")

    try FileManager.default.createDirectory(
      at: outputDirectory,
      withIntermediateDirectories: true
    )
    try? FileManager.default.removeItem(at: outputURL)

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
    process.arguments = ["momc", modelSource.path, outputURL.path]

    let stderrPipe = Pipe()
    process.standardError = stderrPipe

    try process.run()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
      let stderr =
        String(
          data: stderrPipe.fileHandleForReading.readDataToEndOfFile(),
          encoding: .utf8
        ) ?? ""
      throw NSError(
        domain: "GeneratedFlowApp",
        code: Int(process.terminationStatus),
        userInfo: [NSLocalizedDescriptionKey: "momc failed: \(stderr)"]
      )
    }

    return outputURL
  }

  private static func makeContainer(modelURL: URL) throws -> NSPersistentContainer {
    guard let model = NSManagedObjectModel(contentsOf: modelURL) else {
      throw NSError(
        domain: "GeneratedFlowApp",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Failed to load compiled model."]
      )
    }

    let container = NSPersistentContainer(name: "GeneratedFlowModel", managedObjectModel: model)
    let storeURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("GeneratedFlowFixture-\(UUID().uuidString).sqlite")
    let description = NSPersistentStoreDescription(url: storeURL)
    description.type = NSSQLiteStoreType
    description.shouldAddStoreAsynchronously = false
    container.persistentStoreDescriptions = [description]

    var loadError: Error?
    container.loadPersistentStores { _, error in
      loadError = error
    }
    if let loadError {
      throw loadError
    }

    container.viewContext.automaticallyMergesChangesFromParent = true
    return container
  }

  private static func seed(in context: NSManagedObjectContext) throws {
    let project = FlowProject(context: context)
    project.id = UUID()
    project.name = "Schema Lab"

    let task = FlowTask(context: context)
    task.id = UUID()
    task.title = "Review generated flow"
    task.createdAt = Date(timeIntervalSince1970: 1_700_000_000)
    task.status = .review
    task.config = .init(owner: "fatbobman", retryCount: 2, isFlagged: true)
    task.tags = ["generated", "typed-path"]
    task.location = .init(latitude: 31.2304, longitude: 121.4737)
    task.project = project

    try context.save()
  }

  private static func fetchAndAssert(in context: NSManagedObjectContext) throws -> String {
    let request = NSFetchRequest<FlowTask>(entityName: "FlowTask")
    request.sortDescriptors = [
      try NSSortDescriptor(FlowTask.self, path: FlowTask.path.location.latitude, order: .desc),
      try NSSortDescriptor(FlowTask.self, path: FlowTask.path.project.name, order: .asc),
      try NSSortDescriptor(FlowTask.self, path: FlowTask.path.title, order: .asc),
    ]
    request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      FlowTask.path.status.equals(FlowTaskStatus.review),
      FlowTask.path.project.name.equals("Schema Lab"),
      FlowTask.path.location.latitude.greaterThan(30),
    ])

    let tasks = try context.fetch(request)
    guard tasks.count == 1, let task = tasks.first else {
      throw NSError(
        domain: "GeneratedFlowApp",
        code: 2,
        userInfo: [
          NSLocalizedDescriptionKey: "Expected exactly one matching FlowTask, found \(tasks.count)."
        ]
      )
    }

    try assert(task.status == .review, "Expected status == .review.")
    try assert(task.project?.name == "Schema Lab", "Expected project.name == \"Schema Lab\".")
    try assert(
      task.location?.latitude == 31.2304,
      "Expected location.latitude == 31.2304."
    )
    let rawTagsPayload = task.value(forKey: "tags_payload")
    try assert(
      task.tags == ["generated", "typed-path"],
      "Expected tags == [\"generated\", \"typed-path\"]. "
        + "Found tags=\(String(describing: task.tags)), "
        + "raw tags_payload=\(String(describing: rawTagsPayload)), "
        + "raw type=\(String(describing: type(of: rawTagsPayload as Any)))."
    )

    let tags = task.tags?.joined(separator: ",") ?? "nil"
    return
      "\(task.title) | status=\(task.status?.rawValue ?? "nil") | project=\(task.project?.name ?? "nil") | lat=\(task.location?.latitude ?? 0) | tags=\(tags)"
  }

  private static func assert(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    guard condition() else {
      throw NSError(
        domain: "GeneratedFlowApp",
        code: 3,
        userInfo: [NSLocalizedDescriptionKey: message]
      )
    }
  }
}
