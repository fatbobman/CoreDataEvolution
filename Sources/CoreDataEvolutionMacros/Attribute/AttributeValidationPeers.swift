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
    peers.append(
      makeTypeValidationPeer(
        propertyName: info.propertyName,
        suffix: "raw",
        callee: "CoreDataEvolution._CDAttributeMacroValidation.requireRawRepresentable",
        typeName: info.nonOptionalTypeName
      ))
    return peers
  case .codable:
    peers.append(
      makeTypeValidationPeer(
        propertyName: info.propertyName,
        suffix: "codable",
        callee: "CoreDataEvolution._CDAttributeMacroValidation.requireCodable",
        typeName: info.nonOptionalTypeName
      ))
    return peers
  case .transformed(let transformerType):
    peers.append(
      makeTypeValidationPeer(
        propertyName: info.propertyName,
        suffix: "transformed",
        callee: "CoreDataEvolution._CDAttributeMacroValidation.requireTransformer",
        typeName: transformerType
      ))
    return peers
  case .composition:
    peers.append(
      makeTypeValidationPeer(
        propertyName: info.propertyName,
        suffix: "composition",
        callee: "CoreDataEvolution._CDAttributeMacroValidation.requireComposition",
        typeName: info.nonOptionalTypeName
      ))
    return peers
  }
}

private func makeRelationshipDisallowPeer(from info: AttributeInfo) -> DeclSyntax {
  let memberName = "__cd_attribute_validate_\(info.propertyName)_nonrelationship"
  let typeName = info.typeName
  return
    """
    private static let \(raw: memberName): Void = CoreDataEvolution._CDAttributeMacroValidation.requireNonRelationship(\(raw: typeName).self)
    """
}

private func makeTypeValidationPeer(
  propertyName: String,
  suffix: String,
  callee: String,
  typeName: String
) -> DeclSyntax {
  let memberName = "__cd_attribute_validate_\(propertyName)_\(suffix)"
  return
    """
    private static let \(raw: memberName): Void = \(raw: callee)(\(raw: typeName).self)
    """
}
