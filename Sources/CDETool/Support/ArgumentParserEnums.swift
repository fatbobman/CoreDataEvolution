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

import ArgumentParser
import CoreDataEvolutionToolingCore

extension ToolingAccessLevel: ExpressibleByArgument {
  public init?(argument: String) {
    switch argument {
    case "internal":
      self = .internal
    case "public":
      self = .public
    default:
      return nil
    }
  }
}

extension ToolingOverwriteMode: ExpressibleByArgument {}
extension ToolingFormatMode: ExpressibleByArgument {}
extension ToolingDecodeFailurePolicy: ExpressibleByArgument {}
extension ToolingValidationLevel: ExpressibleByArgument {}
extension ToolingReportFormat: ExpressibleByArgument {}
