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

/// Result for the in-memory generate engine.
public struct GenerateResult: Sendable, Equatable {
  public let modelIR: ToolingModelIR
  public let generatedSources: [ToolingGeneratedSource]
  public let filePlan: [ToolingGeneratedFilePlan]
  public let writeResult: ToolingGeneratedWriteResult
  public let diagnostics: [ToolingDiagnostic]

  public init(
    modelIR: ToolingModelIR,
    generatedSources: [ToolingGeneratedSource],
    filePlan: [ToolingGeneratedFilePlan],
    writeResult: ToolingGeneratedWriteResult,
    diagnostics: [ToolingDiagnostic]
  ) {
    self.modelIR = modelIR
    self.generatedSources = generatedSources
    self.filePlan = filePlan
    self.writeResult = writeResult
    self.diagnostics = diagnostics
  }
}

/// Result for validate.
public struct ValidateResult: Codable, Sendable, Equatable {
  public let modelIR: ToolingModelIR
  public let sourceIR: ToolingSourceModelIR
  public let diagnostics: [ToolingDiagnostic]
  public let errorCount: Int
  public let warningCount: Int

  public init(
    modelIR: ToolingModelIR,
    sourceIR: ToolingSourceModelIR,
    diagnostics: [ToolingDiagnostic],
    errorCount: Int? = nil,
    warningCount: Int? = nil
  ) {
    self.modelIR = modelIR
    self.sourceIR = sourceIR
    self.diagnostics = diagnostics
    self.errorCount = errorCount ?? diagnostics.filter { $0.severity == .error }.count
    self.warningCount = warningCount ?? diagnostics.filter { $0.severity == .warning }.count
  }
}

/// Result for `inspect`.
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
