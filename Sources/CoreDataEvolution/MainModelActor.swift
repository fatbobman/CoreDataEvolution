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
import SwiftData

@MainActor
public protocol MainModelActorX: AnyObject {
    /// Provides access to the NSPersistentContainer associated with the NSMainModelActor.
    var modelContainer: ModelContainer { get }
}

extension MainModelActorX {
    /// Exposes the view context for model operations.
    public var modelContext: ModelContext {
        modelContainer.mainContext
    }

    /// Retrieves a model instance based on its identifier, cast to the specified type.
    ///
    /// This method attempts to fetch a model instance from the context using the provided identifier. If the model is not found, it constructs a fetch descriptor with a predicate matching the identifier and attempts to fetch the model. The fetched model is then cast to the specified type.
    ///
    /// - Parameters:
    ///   - id: The identifier of the model to fetch.
    ///   - as: The type to which the fetched model should be cast.
    /// - Returns: The fetched model instance cast to the specified type, or nil if not found.
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
