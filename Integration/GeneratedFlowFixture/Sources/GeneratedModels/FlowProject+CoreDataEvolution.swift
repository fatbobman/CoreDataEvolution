// cde-tool:generated
// Do not edit by hand.
// Regenerate with cde-tool generate.

import CoreData
import CoreDataEvolution
import Foundation

@objc(FlowProject)
@PersistentModel
public final class FlowProject: NSManagedObject {
  public var id: UUID? = nil

  public var name: String = ""

  @Relationship(persistentName: "owned_tasks", inverse: "owner_project", deleteRule: .nullify)
  public var tasks: Set<FlowTask>

}
