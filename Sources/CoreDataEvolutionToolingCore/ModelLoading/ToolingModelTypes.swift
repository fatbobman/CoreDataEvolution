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

public enum ToolingModelInputKind: String, Sendable, Equatable {
  case xcdatamodeld
  case xcdatamodel
  case momd
  case mom
}

public struct ToolingResolvedModelInput: Sendable, Equatable {
  public let originalURL: URL
  public let selectedSourceURL: URL
  public let compiledModelURL: URL
  public let kind: ToolingModelInputKind
  public let selectedVersionName: String?

  public init(
    originalURL: URL,
    selectedSourceURL: URL,
    compiledModelURL: URL,
    kind: ToolingModelInputKind,
    selectedVersionName: String?
  ) {
    self.originalURL = originalURL
    self.selectedSourceURL = selectedSourceURL
    self.compiledModelURL = compiledModelURL
    self.kind = kind
    self.selectedVersionName = selectedVersionName
  }
}
