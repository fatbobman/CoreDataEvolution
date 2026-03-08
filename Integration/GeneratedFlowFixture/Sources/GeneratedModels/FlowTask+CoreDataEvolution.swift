// cde-tool:generated
// Do not edit by hand.
// Regenerate with cde-tool generate.

import CoreData
import CoreDataEvolution
import Foundation

@objc(FlowTask)
@PersistentModel
public final class FlowTask: NSManagedObject {
  @Attribute(
    persistentName: "config_blob", storageMethod: .codable,
    decodeFailurePolicy: .fallbackToDefaultValue)
  public var config: FlowTaskConfig? = nil

  @Attribute(persistentName: "created_at")
  public var createdAt: Date? = nil

  public var id: UUID? = nil

  @Attribute(storageMethod: .composition)
  public var location: FlowPoint? = nil

  @Attribute(persistentName: "name")
  public var title: String = ""

  @Attribute(
    persistentName: "status_raw", storageMethod: .raw, decodeFailurePolicy: .fallbackToDefaultValue)
  public var status: FlowTaskStatus? = nil

  @Attribute(
    persistentName: "tags_payload", storageMethod: .transformed(FlowStringListTransformer.self),
    decodeFailurePolicy: .fallbackToDefaultValue)
  public var tags: [String]? = nil

  @Relationship(persistentName: "owner_project", inverse: "owned_tasks", deleteRule: .nullify)
  public var project: FlowProject?

}
