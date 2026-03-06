//
//  ------------------------------------------------
//  Original project: CoreDataEvolution
//  Created on 2026/3/6 by Fatbobman(东坡肘子)
//  X: @fatbobman
//  Mastodon: @fatbobman@mastodon.social
//  GitHub: @fatbobman
//  Blog: https://fatbobman.com
//  ------------------------------------------------
//  Copyright © 2024-present Fatbobman. All rights reserved.

import Foundation

/// Builds a reusable IR snapshot from the current model plus tooling rules.
///
/// `inspect` stays permissive by design: it emits diagnostics for unresolved fields instead of
/// failing fast so partially-complete bootstrap configs remain inspectable.
public enum InspectService {
  public static func run(_ request: InspectRequest) throws -> InspectResult {
    try ToolingModelLoader.validateSourceModelLayout(
      modelPath: request.modelPath,
      modelVersion: request.modelVersion
    )

    let loadedModel = try ToolingModelLoader.loadModel(
      modelPath: request.modelPath,
      modelVersion: request.modelVersion,
      momcBin: request.momcBin
    )

    let buildResult = ToolingIRBuilder.build(
      from: loadedModel,
      request: request
    )

    do {
      let jsonData = try encodeToolingJSON(buildResult.modelIR)
      return .init(
        modelIR: buildResult.modelIR,
        jsonData: jsonData,
        diagnostics: buildResult.diagnostics
      )
    } catch {
      throw ToolingFailure.runtime(
        .jsonEncodeFailed,
        "failed to encode inspect IR as JSON."
      )
    }
  }
}
