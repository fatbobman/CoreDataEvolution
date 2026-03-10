import CoreData
import CoreDataEvolution

@objc(FlowProject)
final class FlowProject: NSManagedObject {
  var tasks: Set<FlowTask> {
    get {
      // Expose a plain Swift Set<T> at the public API boundary.
      // This bridges and copies the underlying NSSet on every access.
      (value(forKey: "owned_tasks") as? NSSet)?
        .compactMap {
        $0 as? FlowTask
      }
        .reduce(into: Set<FlowTask>()) {
        $0.insert($1)
      }
        ?? []
    }
    set {
      setValue(NSSet(set: newValue), forKey: "owned_tasks")
    }
  }

  enum Keys: RawRepresentable {
    typealias RawValue = String

    init?(rawValue: String) {
      return nil
    }

    var rawValue: String {
      switch self {
      }
    }
  }

  enum Paths {
    static let tasks = CoreDataEvolution.CDToManyRelationPath<FlowProject, FlowTask>(
      swiftPath: ["tasks"],
      persistentPath: ["owned_tasks"]
    )
  }

  struct PathRoot: Sendable {
    var tasks: CoreDataEvolution.CDToManyRelationPath<FlowProject, FlowTask> {
      Paths.tasks
    }
  }

  static var path: PathRoot {
    .init()
  }

  static let __cdRelationshipProjectionTable: [String: CoreDataEvolution.CDFieldMeta] = {
    var table: [String: CoreDataEvolution.CDFieldMeta] = [:]

    return table
  }()

  static let __cdFieldTable: [String: CoreDataEvolution.CDFieldMeta] = {
    var table: [String: CoreDataEvolution.CDFieldMeta] = __cdRelationshipProjectionTable
    table.merge(
      [
    "tasks": .init(
    kind: .relationship,
    swiftPath: ["tasks"],
    persistentPath: ["owned_tasks"],
    storageMethod: .default,
    supportsStoreSort: false,
    isToManyRelationship: true
  )
      ],
      uniquingKeysWith: { _, new in
        new
      }
    )
  table.merge(
    CoreDataEvolution.CDRelationshipTableBuilder.makeToManyFieldEntries(
      modelSwiftPathPrefix: ["tasks"],
      modelPersistentPathPrefix: ["owned_tasks"],
      target: FlowTask.self
    ),
    uniquingKeysWith: { _, new in
      new
    }
  )
    return table
  }()

  static let __cd_relationship_validate_tasks_entity: Void = CoreDataEvolution._CDRelationshipMacroValidation.requirePersistentEntity(FlowTask.self)

  static var __cdRuntimeEntitySchema: CoreDataEvolution.CDRuntimeEntitySchema {
    .init(
      entityName: "FlowProject",
      managedObjectClassName: NSStringFromClass(Self.self),
      attributes: [

      ],
      relationships: [
        CoreDataEvolution.CDRuntimeRelationshipSchema(
    swiftName: "tasks",
    persistentName: "owned_tasks",
    targetTypeName: "FlowTask",
    inverseName: "owner_project",
    deleteRule: .nullify,
    kind: .toManySet,
    isOptional: true
        )
      ],
      uniquenessConstraints: [

      ]
    )
  }

  @nonobjc
  class func fetchRequest() -> NSFetchRequest<FlowProject> {
    NSFetchRequest<FlowProject>(entityName: "FlowProject")
  }

  func addToTasks(_ value: FlowTask) {
    mutableSetValue(forKey: "owned_tasks").add(value)
  }

  func removeFromTasks(_ value: FlowTask) {
    mutableSetValue(forKey: "owned_tasks").remove(value)
  }
}

@objc(FlowTask)
final class FlowTask: NSManagedObject {
  var project: FlowProject? {
    get {
      value(forKey: "owner_project") as? FlowProject
    }
    set {
      setValue(newValue, forKey: "owner_project")
    }
  }

  enum Keys: RawRepresentable {
    typealias RawValue = String

    init?(rawValue: String) {
      return nil
    }

    var rawValue: String {
      switch self {
      }
    }
  }

  enum Paths {
    static let project = CoreDataEvolution.CDToOneRelationPath<FlowTask, FlowProject>(
      swiftPath: ["project"],
      persistentPath: ["owner_project"]
    )
  }

  struct PathRoot: Sendable {
    var project: CoreDataEvolution.CDToOneRelationPath<FlowTask, FlowProject> {
      Paths.project
    }
  }

  static var path: PathRoot {
    .init()
  }

  static let __cdRelationshipProjectionTable: [String: CoreDataEvolution.CDFieldMeta] = {
    var table: [String: CoreDataEvolution.CDFieldMeta] = [:]

    return table
  }()

  static let __cdFieldTable: [String: CoreDataEvolution.CDFieldMeta] = {
    var table: [String: CoreDataEvolution.CDFieldMeta] = __cdRelationshipProjectionTable
    table.merge(
      [
    "project": .init(
    kind: .relationship,
    swiftPath: ["project"],
    persistentPath: ["owner_project"],
    storageMethod: .default,
    supportsStoreSort: false,
    isToManyRelationship: false
  )
      ],
      uniquingKeysWith: { _, new in
        new
      }
    )
  table.merge(
    CoreDataEvolution.CDRelationshipTableBuilder.makeToOneFieldEntries(
      modelSwiftPathPrefix: ["project"],
      modelPersistentPathPrefix: ["owner_project"],
      target: FlowProject.self
    ),
    uniquingKeysWith: { _, new in
      new
    }
  )
    return table
  }()

  static let __cd_relationship_validate_project_entity: Void = CoreDataEvolution._CDRelationshipMacroValidation.requirePersistentEntity(FlowProject.self)

  static var __cdRuntimeEntitySchema: CoreDataEvolution.CDRuntimeEntitySchema {
    .init(
      entityName: "FlowTask",
      managedObjectClassName: NSStringFromClass(Self.self),
      attributes: [

      ],
      relationships: [
        CoreDataEvolution.CDRuntimeRelationshipSchema(
    swiftName: "project",
    persistentName: "owner_project",
    targetTypeName: "FlowProject",
    inverseName: "owned_tasks",
    deleteRule: .nullify,
    kind: .toOne,
    isOptional: true
        )
      ],
      uniquenessConstraints: [

      ]
    )
  }

  @nonobjc
  class func fetchRequest() -> NSFetchRequest<FlowTask> {
    NSFetchRequest<FlowTask>(entityName: "FlowTask")
  }
}

extension FlowProject: CoreDataEvolution.PersistentEntity, CoreDataEvolution.CDRuntimeSchemaProviding {
}

extension FlowTask: CoreDataEvolution.PersistentEntity, CoreDataEvolution.CDRuntimeSchemaProviding {
}