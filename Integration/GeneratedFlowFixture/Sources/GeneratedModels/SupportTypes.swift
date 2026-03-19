@preconcurrency import CoreDataEvolution
import Foundation

public enum FlowTaskStatus: String, Sendable {
  case backlog
  case review
  case done
}

public struct FlowTaskConfig: Codable, Sendable, Equatable {
  public var owner: String
  public var retryCount: Int
  public var isFlagged: Bool

  public init(owner: String, retryCount: Int, isFlagged: Bool) {
    self.owner = owner
    self.retryCount = retryCount
    self.isFlagged = isFlagged
  }
}

@Composition
public struct FlowPoint: Sendable, Equatable {
  @CompositionField(persistentName: "lat")
  public var latitude: Double = 0

  @CompositionField(persistentName: "lng")
  public var longitude: Double? = nil

  public init(latitude: Double = 0, longitude: Double? = nil) {
    self.latitude = latitude
    self.longitude = longitude
  }
}

public enum FixtureSupport {
  public static func compileModel(filePath: String = #filePath) throws -> URL {
    let fileURL = URL(fileURLWithPath: filePath)
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
        domain: "GeneratedFlowFixture",
        code: Int(process.terminationStatus),
        userInfo: [NSLocalizedDescriptionKey: "momc failed: \(stderr)"]
      )
    }

    return outputURL
  }

  public static func makeContainer(modelURL: URL) throws -> NSPersistentContainer {
    guard let model = NSManagedObjectModel(contentsOf: modelURL) else {
      throw NSError(
        domain: "GeneratedFlowFixture",
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
}
