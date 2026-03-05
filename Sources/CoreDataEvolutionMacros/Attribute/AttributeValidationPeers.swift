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
  switch info.storageMethod {
  case .default:
    return []
  case .raw:
    let functionName = "__cd_attribute_validate_\(info.propertyName)_raw"
    let typeName = info.nonOptionalTypeName
    return [
      """
      private func \(raw: functionName)() {
        func __cdRequireRawRepresentable<T: RawRepresentable>(_: T.Type) {}
        __cdRequireRawRepresentable(\(raw: typeName).self)
      }
      """
    ]
  case .codable:
    let functionName = "__cd_attribute_validate_\(info.propertyName)_codable"
    let typeName = info.nonOptionalTypeName
    return [
      """
      private func \(raw: functionName)() {
        func __cdRequireCodable<T: Codable>(_: T.Type) {}
        __cdRequireCodable(\(raw: typeName).self)
      }
      """
    ]
  case .transformed(let transformerType):
    let functionName = "__cd_attribute_validate_\(info.propertyName)_transformed"
    return [
      """
      private func \(raw: functionName)() {
        func __cdRequireTransformer<T: ValueTransformer>(_: T.Type) {}
        __cdRequireTransformer(\(raw: transformerType))
      }
      """
    ]
  case .composition:
    let functionName = "__cd_attribute_validate_\(info.propertyName)_composition"
    let typeName = info.nonOptionalTypeName
    return [
      """
      private func \(raw: functionName)() {
        func __cdRequireComposition<T: CDCompositionValueCodable & CDCompositionPathProviding>(_: T.Type) {}
        __cdRequireComposition(\(raw: typeName).self)
      }
      """
    ]
  }
}
