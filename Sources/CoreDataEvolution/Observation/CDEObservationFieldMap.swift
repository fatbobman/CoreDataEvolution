//
//  ------------------------------------------------
//  Original project: CoreDataEvolution
//  Created on 2026/5/31 by Fatbobman(东坡肘子)
//  X: @fatbobman
//  Mastodon: @fatbobman@mastodon.social
//  GitHub: @fatbobman
//  Blog: https://fatbobman.com
//  ------------------------------------------------
//  Copyright © 2024-present Fatbobman. All rights reserved.

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
/// Compact set of macro-generated observation field IDs.
///
/// Raw IDs are local to one generated model type; never compare them across model types.
public struct CDEObservationFieldSet: Equatable, Sendable {
  public private(set) var rawChunks: [UInt64]

  public init() {
    rawChunks = []
  }

  public init(rawValues: [UInt16]) {
    self.init()
    for rawValue in rawValues {
      insert(rawValue: rawValue)
    }
  }

  public var isEmpty: Bool {
    rawChunks.allSatisfy { $0 == 0 }
  }

  public var count: Int {
    rawChunks.reduce(0) { $0 + $1.nonzeroBitCount }
  }

  public var rawValues: [UInt16] {
    var values: [UInt16] = []
    for (chunkIndex, chunk) in rawChunks.enumerated() where chunk != 0 {
      for bitIndex in 0..<64 {
        let bit = UInt64(1) << UInt64(bitIndex)
        guard chunk & bit != 0 else { continue }
        values.append(UInt16(chunkIndex * 64 + bitIndex))
      }
    }
    return values
  }

  public mutating func insert(rawValue: UInt16) {
    let chunkIndex = Int(rawValue) / 64
    let bitIndex = Int(rawValue) % 64
    if rawChunks.count <= chunkIndex {
      rawChunks.append(contentsOf: repeatElement(0, count: chunkIndex - rawChunks.count + 1))
    }
    rawChunks[chunkIndex] |= UInt64(1) << UInt64(bitIndex)
  }

  public func contains(rawValue: UInt16) -> Bool {
    let chunkIndex = Int(rawValue) / 64
    guard rawChunks.indices.contains(chunkIndex) else {
      return false
    }
    let bitIndex = Int(rawValue) % 64
    return rawChunks[chunkIndex] & (UInt64(1) << UInt64(bitIndex)) != 0
  }

  public func union(_ other: CDEObservationFieldSet) -> CDEObservationFieldSet {
    var result = self
    if result.rawChunks.count < other.rawChunks.count {
      result.rawChunks.append(
        contentsOf: repeatElement(0, count: other.rawChunks.count - result.rawChunks.count)
      )
    }
    for (index, chunk) in other.rawChunks.enumerated() {
      result.rawChunks[index] |= chunk
    }
    result.removeTrailingEmptyChunks()
    return result
  }

  private mutating func removeTrailingEmptyChunks() {
    while rawChunks.last == 0 {
      rawChunks.removeLast()
    }
  }
}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
/// Maps Core Data `changedValues()` keys to model-local observable fields.
public struct CDEObservationFieldMap: Equatable, Sendable {
  public let fieldsByCoreDataKey: [String: CDEObservationFieldSet]

  public init(fieldsByCoreDataKey: [String: CDEObservationFieldSet]) {
    self.fieldsByCoreDataKey = fieldsByCoreDataKey
  }

  public func fieldSet<CoreDataKeys>(
    forCoreDataKeys coreDataKeys: CoreDataKeys
  ) -> CDEObservationFieldSet where CoreDataKeys: Sequence, CoreDataKeys.Element == String {
    coreDataKeys.reduce(into: CDEObservationFieldSet()) { result, key in
      result = result.union(fieldsByCoreDataKey[key] ?? CDEObservationFieldSet())
    }
  }
}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
/// Runtime witness surface emitted by `@PersistentModel(observation: .mainActor)`.
public protocol CDEObservationFieldMapProviding {
  static var __cdObservationFieldMap: CDEObservationFieldMap { get }

  static func __cdObservationFieldSet<CoreDataKeys>(
    forCoreDataKeys coreDataKeys: CoreDataKeys
  ) -> CDEObservationFieldSet where CoreDataKeys: Sequence, CoreDataKeys.Element == String

  static func __cdObservationKeyPaths(
    for fieldSet: CDEObservationFieldSet
  ) -> [PartialKeyPath<Self>]
}
