//
//  ------------------------------------------------
//  Original project: CoreDataEvolution
//  Created on 2026/3/5 by Fatbobman(东坡肘子)
//  X: @fatbobman
//  Mastodon: @fatbobman@mastodon.social
//  GitHub: @fatbobman
//  Blog: https://fatbobman.com
//  ------------------------------------------------
//  Copyright © 2024-present Fatbobman. All rights reserved.

import SwiftSyntax

func makeAttributeValidationPeers(from info: AttributeInfo) -> [DeclSyntax] {
  var peers: [DeclSyntax] = [makeRelationshipDisallowPeer(from: info)]

  switch info.storageMethod {
  case .default:
    return peers
  case .raw:
    let functionName = "__cd_attribute_validate_\(info.propertyName)_raw"
    let typeName = info.nonOptionalTypeName
    peers.append(
      """
      private func \(raw: functionName)() {
        func __cdRequireRawRepresentable<T: RawRepresentable>(_: T.Type) {}
        __cdRequireRawRepresentable(\(raw: typeName).self)
      }
      """
    )
    return peers
  case .codable:
    let functionName = "__cd_attribute_validate_\(info.propertyName)_codable"
    let typeName = info.nonOptionalTypeName
    peers.append(
      """
      private func \(raw: functionName)() {
        func __cdRequireCodable<T: Codable>(_: T.Type) {}
        __cdRequireCodable(\(raw: typeName).self)
      }
      """
    )
    return peers
  case .transformed(let transformerType):
    let functionName = "__cd_attribute_validate_\(info.propertyName)_transformed"
    peers.append(
      """
      private func \(raw: functionName)() {
        func __cdRequireTransformer<T: ValueTransformer>(_: T.Type) {}
        __cdRequireTransformer(\(raw: transformerType))
      }
      """
    )
    return peers
  case .composition:
    let functionName = "__cd_attribute_validate_\(info.propertyName)_composition"
    let typeName = info.nonOptionalTypeName
    peers.append(
      """
      private func \(raw: functionName)() {
        func __cdRequireComposition<T: CDCompositionValueCodable & CDCompositionPathProviding>(_: T.Type) {}
        __cdRequireComposition(\(raw: typeName).self)
      }
      """
    )
    return peers
  }
}

private func makeRelationshipDisallowPeer(from info: AttributeInfo) -> DeclSyntax {
  let functionName = "__cd_attribute_validate_\(info.propertyName)_nonrelationship"
  let typeName = info.typeName
  return
    """
    private func \(raw: functionName)() {
      func __cdDisallowRelationship<T>(_: T.Type) {}
      @available(*, unavailable, message: "@Attribute cannot be applied to relationship properties. Remove @Attribute from this property.")
      func __cdDisallowRelationship<T: NSManagedObject>(_: T.Type) {}
      @available(*, unavailable, message: "@Attribute cannot be applied to to-one relationship properties (`T?` where `T: NSManagedObject`).")
      func __cdDisallowRelationship<T: NSManagedObject>(_: Optional<T>.Type) {}
      @available(*, unavailable, message: "@Attribute cannot be applied to to-many relationship properties (`Set<T>` where `T: NSManagedObject`).")
      func __cdDisallowRelationship<T: NSManagedObject>(_: Set<T>.Type) {}
      @available(*, unavailable, message: "@Attribute cannot be applied to ordered to-many relationship properties (`[T]` where `T: NSManagedObject`).")
      func __cdDisallowRelationship<T: NSManagedObject>(_: Array<T>.Type) {}
      __cdDisallowRelationship(\(raw: typeName).self)
    }
    """
}
