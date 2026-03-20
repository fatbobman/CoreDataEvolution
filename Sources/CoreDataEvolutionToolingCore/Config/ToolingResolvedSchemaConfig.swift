//
//  ------------------------------------------------
//  Original project: CoreDataEvolution
//  Created on 2026/3/10 by Fatbobman(东坡肘子)
//  X: @fatbobman
//  Mastodon: @fatbobman@mastodon.social
//  GitHub: @fatbobman
//  Blog: https://fatbobman.com
//  ------------------------------------------------
//  Copyright © 2024-present Fatbobman. All rights reserved.

import Foundation

/// Shared schema-facing options consumed by generate, validate, and inspect.
///
/// Tooling templates and runtime requests both carry these rules. Centralizing them keeps later
/// validation and IR-building paths aligned without reconstructing config templates inside
/// services.
struct ToolingResolvedSchemaConfig: Sendable, Equatable {
  let typeMappings: ToolingTypeMappings
  let attributeRules: ToolingAttributeRules
  let relationshipRules: ToolingRelationshipRules
  let compositionRules: ToolingCompositionRules
  let accessLevel: ToolingAccessLevel
  let singleFile: Bool
  let splitByEntity: Bool
  let headerTemplate: String?
  let generateInit: Bool
  let generateToManyCount: Bool
  let defaultDecodeFailurePolicy: ToolingDecodeFailurePolicy
}

extension ToolingResolvedSchemaConfig {
  init(generateTemplate: GenerateTemplate) {
    self.init(
      typeMappings: mergeToolingTypeMappings(generateTemplate.typeMappings),
      attributeRules: generateTemplate.attributeRules ?? .init(),
      relationshipRules: generateTemplate.relationshipRules ?? .init(),
      compositionRules: generateTemplate.compositionRules ?? .init(),
      accessLevel: generateTemplate.accessLevel ?? .internal,
      singleFile: generateTemplate.singleFile ?? false,
      splitByEntity: generateTemplate.splitByEntity ?? true,
      headerTemplate: generateTemplate.headerTemplate,
      generateInit: generateTemplate.generateInit ?? false,
      generateToManyCount: generateTemplate.generateToManyCount ?? true,
      defaultDecodeFailurePolicy: generateTemplate.defaultDecodeFailurePolicy
        ?? .fallbackToDefaultValue
    )
  }

  init(validateTemplate: ValidateTemplate) {
    self.init(
      typeMappings: mergeToolingTypeMappings(validateTemplate.typeMappings),
      attributeRules: validateTemplate.attributeRules ?? .init(),
      relationshipRules: validateTemplate.relationshipRules ?? .init(),
      compositionRules: validateTemplate.compositionRules ?? .init(),
      accessLevel: validateTemplate.accessLevel ?? .internal,
      singleFile: validateTemplate.singleFile ?? false,
      splitByEntity: validateTemplate.splitByEntity ?? true,
      headerTemplate: validateTemplate.headerTemplate,
      generateInit: validateTemplate.generateInit ?? false,
      generateToManyCount: validateTemplate.generateToManyCount ?? true,
      defaultDecodeFailurePolicy: validateTemplate.defaultDecodeFailurePolicy
        ?? .fallbackToDefaultValue
    )
  }

  init(generateRequest: GenerateRequest) {
    self.init(
      typeMappings: generateRequest.typeMappings,
      attributeRules: generateRequest.attributeRules,
      relationshipRules: generateRequest.relationshipRules,
      compositionRules: generateRequest.compositionRules,
      accessLevel: generateRequest.accessLevel,
      singleFile: generateRequest.singleFile,
      splitByEntity: generateRequest.splitByEntity,
      headerTemplate: generateRequest.headerTemplate,
      generateInit: generateRequest.generateInit,
      generateToManyCount: generateRequest.generateToManyCount,
      defaultDecodeFailurePolicy: generateRequest.defaultDecodeFailurePolicy
    )
  }

  init(validateRequest: ValidateRequest) {
    self.init(
      typeMappings: validateRequest.typeMappings,
      attributeRules: validateRequest.attributeRules,
      relationshipRules: validateRequest.relationshipRules,
      compositionRules: validateRequest.compositionRules,
      accessLevel: validateRequest.accessLevel,
      singleFile: validateRequest.singleFile,
      splitByEntity: validateRequest.splitByEntity,
      headerTemplate: validateRequest.headerTemplate,
      generateInit: validateRequest.generateInit,
      generateToManyCount: validateRequest.generateToManyCount,
      defaultDecodeFailurePolicy: validateRequest.defaultDecodeFailurePolicy
    )
  }
}
