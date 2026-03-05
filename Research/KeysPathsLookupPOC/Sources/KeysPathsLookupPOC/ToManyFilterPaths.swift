import Foundation

/// Entry path for to-many relationships, e.g. `Model.path.tags`.
public struct CDToManyRelationPath<
  Root: CoreDataPathTable,
  Target: CoreDataPathDSLProviding
>: @unchecked Sendable {
  public let swiftPath: [String]
  public let persistentPath: [String]

  public init(swiftPath: [String], persistentPath: [String]) {
    self.swiftPath = swiftPath
    self.persistentPath = persistentPath
  }

  public var any: CDQuantifiedToManyPath<Root, Target> {
    CDQuantifiedToManyPath(quantifier: .any, relationshipSwiftPath: swiftPath)
  }

  public var all: CDQuantifiedToManyPath<Root, Target> {
    CDQuantifiedToManyPath(quantifier: .all, relationshipSwiftPath: swiftPath)
  }

  public var none: CDQuantifiedToManyPath<Root, Target> {
    CDQuantifiedToManyPath(quantifier: .none, relationshipSwiftPath: swiftPath)
  }
}

/// Quantified path that forwards members from target `PathRoot`.
@dynamicMemberLookup
public struct CDQuantifiedToManyPath<
  Root: CoreDataPathTable,
  Target: CoreDataPathDSLProviding
>: @unchecked Sendable {
  public let quantifier: CDCollectionQuantifier
  public let relationshipSwiftPath: [String]

  public init(
    quantifier: CDCollectionQuantifier,
    relationshipSwiftPath: [String]
  ) {
    self.quantifier = quantifier
    self.relationshipSwiftPath = relationshipSwiftPath
  }

  public subscript<Value>(
    dynamicMember keyPath: KeyPath<Target.PathRoot, CDPath<Target, Value>>
  ) -> CDFilterField<Root, Value> {
    let targetPath = Target.path[keyPath: keyPath]
    return CDFilterField(
      swiftPath: relationshipSwiftPath + targetPath.swiftPath,
      quantifier: quantifier
    )
  }
}
