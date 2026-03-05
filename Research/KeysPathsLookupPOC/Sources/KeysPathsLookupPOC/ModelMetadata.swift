import Foundation

/// Storage strategy used by macro-generated accessors.
public enum StorageMethod: Equatable, Sendable {
  case `default`
  case raw
  case codable
  case transformed
  case composition
}

/// High-level field kind in the model table.
public enum CDFieldKind: Equatable, Sendable {
  case attribute
  case relationship
  case composition
}

/// Unified metadata entry used by sort/filter path mapping.
public struct CDFieldMeta: Equatable, Sendable {
  public let kind: CDFieldKind
  public let swiftPath: [String]
  public let persistentPath: [String]
  public let storageMethod: StorageMethod
  public let supportsStoreSort: Bool
  public let isToManyRelationship: Bool

  public init(
    kind: CDFieldKind,
    swiftPath: [String],
    persistentPath: [String],
    storageMethod: StorageMethod,
    supportsStoreSort: Bool,
    isToManyRelationship: Bool = false
  ) {
    self.kind = kind
    self.swiftPath = swiftPath
    self.persistentPath = persistentPath
    self.storageMethod = storageMethod
    self.supportsStoreSort = supportsStoreSort
    self.isToManyRelationship = isToManyRelationship
  }
}

/// Strongly-typed path token shared by sort and predicate builders.
public struct CDPath<Root, Value>: @unchecked Sendable {
  public let swiftPath: [String]
  public let persistentPath: [String]
  public let storageMethod: StorageMethod

  public init(
    swiftPath: [String],
    persistentPath: [String],
    storageMethod: StorageMethod = .default
  ) {
    self.swiftPath = swiftPath
    self.persistentPath = persistentPath
    self.storageMethod = storageMethod
  }

  public var swiftPathKey: String {
    swiftPath.joined(separator: ".")
  }

  public var persistentPathKey: String {
    persistentPath.joined(separator: ".")
  }

  /// Convenience alias for persistent field key/path.
  public var raw: String {
    persistentPathKey
  }
}
