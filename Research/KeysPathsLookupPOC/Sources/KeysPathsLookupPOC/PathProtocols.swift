import Foundation

/// Type that exposes the global path metadata table.
public protocol CoreDataPathTable {
  static var __cdFieldTable: [String: CDFieldMeta] { get }
}

/// Type that exposes flat string keys for sort/filter APIs.
public protocol CoreDataKeys: CoreDataPathTable {
  associatedtype Keys: RawRepresentable where Keys.RawValue == String
}

/// Type that exposes chainable path DSL, e.g. `Model.path.name`.
public protocol CoreDataPathDSLProviding: CoreDataPathTable {
  associatedtype PathRoot
  static var path: PathRoot { get }
}

extension CoreDataPathTable {
  public static func __cdMeta(forSwiftPath swiftPath: [String]) -> CDFieldMeta? {
    __cdFieldTable[swiftPath.joined(separator: ".")]
  }

  public static func __cdMeta(forSwiftPath swiftPath: String) -> CDFieldMeta? {
    __cdFieldTable[swiftPath]
  }

  public static func __cdPersistentPath(forSwiftPath swiftPath: String) -> String? {
    __cdFieldTable[swiftPath]?.persistentPath.joined(separator: ".")
  }
}
