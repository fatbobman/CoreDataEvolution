//
//  ------------------------------------------------
//  Original project: CoreDataEvolution
//  Created on 2024/10/30 by Fatbobman(东坡肘子)
//  X: @fatbobman
//  Mastodon: @fatbobman@mastodon.social
//  GitHub: @fatbobman
//  Blog: https://fatbobman.com
//  ------------------------------------------------
//  Copyright © 2024-present Fatbobman. All rights reserved.

import Foundation

#if canImport(SwiftData)
  public import SwiftData

  /// Legacy SwiftData bridge retained from earlier iterations of the project.
  ///
  /// This protocol is not part of the main CoreDataEvolution API surface. It exists only as a
  /// lightweight compatibility helper for code that wants the same convenience subscript and
  /// `modelContext` access pattern on SwiftData's `ModelContainer`.
  @available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
  @MainActor
  public protocol MainModelActorX: AnyObject {
    /// The SwiftData container backing this compatibility layer.
    var modelContainer: ModelContainer { get }
  }
  @available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
  extension MainModelActorX {
    /// The main SwiftData context exposed by the container.
    public var modelContext: ModelContext {
      modelContainer.mainContext
    }

    /// Looks up a SwiftData model by identifier and downcasts it to the requested type.
    public subscript<T>(id: PersistentIdentifier, as: T.Type) -> T? where T: PersistentModel {
      let predicate = #Predicate<T> {
        $0.persistentModelID == id
      }
      if let object: T = modelContext.registeredModel(for: id) {
        return object
      }
      let fetchDescriptor = FetchDescriptor<T>(predicate: predicate)
      let object: T? = try? modelContext.fetch(fetchDescriptor).first
      return object
    }
  }
#endif
