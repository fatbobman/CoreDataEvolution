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

/// Emits static config templates without touching any model files.
public enum InitConfigService {
  public static func run(_ request: InitConfigRequest) throws -> InitConfigResult {
    let template = makeDefaultConfigTemplate(preset: request.preset)

    do {
      let data = try encodeToolingJSON(template)
      return .init(
        template: template,
        jsonData: data,
        diagnostics: []
      )
    } catch {
      throw ToolingFailure.runtime(
        .jsonEncodeFailed,
        "failed to encode config template as JSON."
      )
    }
  }
}
