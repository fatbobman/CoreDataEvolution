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

/// Result for `init-config`.
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

/// Result for `bootstrap-config`.
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

/// Placeholder result model for future generate engine output.
public struct GenerateResult: Sendable, Equatable {
  public let diagnostics: [ToolingDiagnostic]

  public init(diagnostics: [ToolingDiagnostic]) {
    self.diagnostics = diagnostics
  }
}

/// Placeholder result model for future validate engine output.
public struct ValidateResult: Sendable, Equatable {
  public let diagnostics: [ToolingDiagnostic]

  public init(diagnostics: [ToolingDiagnostic]) {
    self.diagnostics = diagnostics
  }
}

/// Placeholder result model for future inspect engine output.
public struct InspectResult: Sendable, Equatable {
  public let modelIR: ToolingModelIR
  public let jsonData: Data
  public let diagnostics: [ToolingDiagnostic]

  public init(
    modelIR: ToolingModelIR,
    jsonData: Data,
    diagnostics: [ToolingDiagnostic]
  ) {
    self.modelIR = modelIR
    self.jsonData = jsonData
    self.diagnostics = diagnostics
  }
}
