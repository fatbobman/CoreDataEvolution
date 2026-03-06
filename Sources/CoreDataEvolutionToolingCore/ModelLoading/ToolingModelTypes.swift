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

/// The concrete kind of model input selected by the loader.
public enum ToolingModelInputKind: String, Sendable, Equatable {
  case xcdatamodeld
  case xcdatamodel
  case momd
  case mom
}

/// Captures how an input path was resolved before it becomes an `NSManagedObjectModel`.
///
/// This keeps later layers independent from filesystem and version-selection details.
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

/// Holds the temporary compile root alive for as long as a loaded source model is retained.
///
/// Source models are compiled into a unique temp directory. Tying cleanup to the loaded-model
/// lifetime avoids leaking `.mom` / `.momd` artifacts across repeated CLI runs.
public final class ToolingTemporaryArtifactToken: @unchecked Sendable {
  private let rootURL: URL?

  public init(rootURL: URL?) {
    self.rootURL = rootURL
  }

  deinit {
    guard let rootURL else { return }
    try? FileManager.default.removeItem(at: rootURL)
  }
}
