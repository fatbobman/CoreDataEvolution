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

public struct InitConfigResult: Sendable {
  public let template: ToolingConfigTemplate
  public let jsonData: Data
  public let diagnostics: [ToolingDiagnostic]

  public init(
    template: ToolingConfigTemplate,
    jsonData: Data,
    diagnostics: [ToolingDiagnostic]
  ) {
    self.template = template
    self.jsonData = jsonData
    self.diagnostics = diagnostics
  }
}

public struct BootstrapConfigResult: Sendable {
  public let template: ToolingConfigTemplate
  public let jsonData: Data
  public let diagnostics: [ToolingDiagnostic]

  public init(
    template: ToolingConfigTemplate,
    jsonData: Data,
    diagnostics: [ToolingDiagnostic]
  ) {
    self.template = template
    self.jsonData = jsonData
    self.diagnostics = diagnostics
  }
}

public struct GenerateResult: Sendable, Equatable {
  public let diagnostics: [ToolingDiagnostic]

  public init(diagnostics: [ToolingDiagnostic]) {
    self.diagnostics = diagnostics
  }
}

public struct ValidateResult: Sendable, Equatable {
  public let diagnostics: [ToolingDiagnostic]

  public init(diagnostics: [ToolingDiagnostic]) {
    self.diagnostics = diagnostics
  }
}

public struct InspectResult: Sendable, Equatable {
  public let diagnostics: [ToolingDiagnostic]

  public init(diagnostics: [ToolingDiagnostic]) {
    self.diagnostics = diagnostics
  }
}
