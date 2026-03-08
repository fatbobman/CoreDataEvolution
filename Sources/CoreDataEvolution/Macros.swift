//
//  Macros.swift
//
//
//  Created by Yang Xu on 2024/4/9.
//

import Foundation

// MARK: - Core Data Macro

/// Declares how a persisted property is stored in the Core Data model.
///
/// Use `.default` when the Swift property type already matches the Core Data field shape.
/// Use the custom storage methods when the Swift-facing type is richer than the persisted value.
public enum AttributeStorageMethod {
  /// Uses the property's declared Swift type as the persisted representation.
  case `default`
  /// Stores a `RawRepresentable` value through its raw primitive backing value.
  case raw
  /// Stores a `Codable` value through encoded binary payload.
  case codable
  /// Stores a value through a `ValueTransformer`.
  case transformed(ValueTransformer.Type)
  /// Stores a value through a Core Data composite attribute.
  case composition
}

/// Controls how generated accessors respond when decoding or reverse transformation fails.
public enum AttributeDecodeFailurePolicy {
  /// Falls back to the property's declared default value.
  ///
  /// For `.codable` and `.transformed`, current rules only allow optional declarations, so this
  /// effectively falls back to `nil`.
  case fallbackToDefaultValue
  /// Triggers a debug assertion and then returns `nil`.
  case debugAssertNil
}

/// Additional attribute-level traits that are orthogonal to the storage method.
public enum AttributeTrait {
  /// Marks the property as a uniqueness constraint in the Core Data model.
  case unique
  /// Marks the property as transient in the Core Data model.
  case transient
}

/// Supported Core Data relationship delete rules.
///
/// `noAction` is intentionally unsupported.
public enum RelationshipDeleteRule: String, Sendable, Codable {
  case nullify
  case cascade
  case deny
}

/// Synthesizes an actor backed by a private Core Data context and a custom serial executor.
///
/// The generated actor:
/// - stores an `NSPersistentContainer`
/// - creates a background `NSManagedObjectContext`
/// - exposes `modelExecutor`
/// - optionally synthesizes `init(container:)`
///
/// Use this when Core Data work should run off the main actor.
///
/// - Parameter disableGenerateInit: When `true`, the macro does not synthesize
///   `init(container:)` and your type must initialize the generated stored properties itself.
@attached(member, names: named(modelExecutor), named(modelContainer), named(init))
@attached(extension, conformances: NSModelActor)
public macro NSModelActor(disableGenerateInit: Bool = false) =
  #externalMacro(module: "CoreDataEvolutionMacros", type: "NSModelActorMacro")

/// Synthesizes a main-actor wrapper around `container.viewContext`.
///
/// The generated type stores an `NSPersistentContainer`, exposes `modelContext` through
/// `viewContext`, and optionally synthesizes `init(modelContainer:)`.
///
/// The attached type itself should still be marked `@MainActor`.
///
/// - Parameter disableGenerateInit: When `true`, the macro does not synthesize
///   `init(modelContainer:)`.
@attached(member, names: named(modelContainer), named(init))
@attached(extension, conformances: NSMainModelActor)
public macro NSMainModelActor(disableGenerateInit: Bool = false) =
  #externalMacro(module: "CoreDataEvolutionMacros", type: "NSMainModelActorMacro")

/// Declares a composition value type used by `.composition` storage.
///
/// The attached type must be a non-generic `struct`. Its stored properties describe the
/// composition leaf fields that participate in typed path mapping and runtime schema generation.
@attached(
  member,
  names: named(__cdCompositionFieldTable), named(__cdFieldTable), named(Paths), named(PathRoot),
  named(path), named(__cdDecodeComposition), named(__cdEncodeComposition),
  named(__cdRuntimeCompositionFields)
)
@attached(
  extension,
  conformances: CDCompositionPathProviding, CDCompositionValueCodable, CoreDataPathDSLProviding,
  CDRuntimeCompositionSchemaProviding
)
public macro Composition() =
  #externalMacro(module: "CoreDataEvolutionMacros", type: "CompositionMacro")

/// Renames a composition leaf field in the Core Data model while keeping a different Swift name.
///
/// Example:
/// ```swift
/// @Composition
/// struct GeoPoint {
///   @CompositionField(persistentName: "lat")
///   var latitude: Double = 0
/// }
/// ```
///
/// - Parameter persistentName: The leaf field name stored in the Core Data composite attribute.
@attached(peer)
public macro CompositionField(
  persistentName: String? = nil
) = #externalMacro(module: "CoreDataEvolutionMacros", type: "CompositionFieldMacro")

/// Excludes a stored property from persistence while keeping it in generated initializers.
@attached(peer)
public macro Ignore() =
  #externalMacro(module: "CoreDataEvolutionMacros", type: "IgnoreMacro")

/// Declares the metadata required for every Core Data relationship property.
///
/// The relationship shape still comes from the Swift property type:
/// - `Target?` for to-one
/// - `Set<Target>` for unordered to-many
/// - `[Target]` for ordered to-many
///
/// `inverse` uses the persistent relationship name from the Core Data model, not the Swift
/// property name on the target type.
///
/// - Parameters:
///   - persistentName: The relationship name stored in the Core Data model when it differs from
///     the Swift property name.
///   - inverse: The persistent relationship name on the destination entity.
///   - deleteRule: The Core Data delete rule for this relationship.
///   - minimumModelCount: Optional explicit minimum relationship count from the model.
///   - maximumModelCount: Optional explicit maximum relationship count from the model. For to-many
///     relationships, `0` means "unbounded" in Core Data.
@attached(peer)
public macro Relationship(
  persistentName: String? = nil,
  inverse: String,
  deleteRule: RelationshipDeleteRule,
  minimumModelCount: Int? = nil,
  maximumModelCount: Int? = nil
) = #externalMacro(module: "CoreDataEvolutionMacros", type: "PublicRelationshipMacro")

/// Internal relationship accessor macro automatically attached by `@PersistentModel`.
///
/// Do not use this macro directly in user code.
@attached(accessor)
public macro _CDRelationship(
  persistentName: String? = nil,
  _fromPersistentModel: Bool = false
) = #externalMacro(module: "CoreDataEvolutionMacros", type: "RelationshipMacro")

/// Declares a Core Data-backed model type.
///
/// `@PersistentModel` is the Swift-facing representation layer for a Core Data entity. It expects
/// the entity to already exist in the Core Data model and keeps the generated code aligned with
/// that schema.
///
/// The attached type must be an `NSManagedObject` subclass with a matching `@objc(EntityName)`
/// declaration.
///
/// Generated members include:
/// - typed key/path metadata
/// - `fetchRequest()`
/// - runtime schema metadata used by test/debug model building
/// - attribute and relationship accessors
/// - an optional memberwise convenience initializer
///
/// - Parameter generateInit: When `true`, synthesizes an initializer that includes all non-
///   relationship stored properties, including `@Ignore` and custom-storage persisted properties.
///   Relationship properties are excluded and no parameter gets a default argument.
@attached(memberAttribute)
@attached(member, names: arbitrary, named(__cdRuntimeEntitySchema))
@attached(extension, conformances: PersistentEntity, CDRuntimeSchemaProviding)
public macro PersistentModel(
  generateInit: Bool = false
) = #externalMacro(module: "CoreDataEvolutionMacros", type: "PersistentModelMacro")

/// Declares metadata for a persisted attribute.
///
/// Use `persistentName` when the Swift property name differs from the Core Data attribute name.
/// This is a present-day storage mapping, not a migration hint like SwiftData's `originalName`.
///
/// - Parameters:
///   - traits: Extra attribute traits such as `.unique` or `.transient`.
///   - persistentName: The Core Data attribute name when it differs from the Swift property name.
///   - storageMethod: The storage strategy used by the generated accessors.
///   - decodeFailurePolicy: Decode failure handling for storage methods that decode values.
@attached(accessor)
@attached(peer, names: arbitrary)
public macro Attribute(
  _ traits: AttributeTrait...,
  persistentName: String? = nil,
  storageMethod: AttributeStorageMethod? = nil,
  decodeFailurePolicy: AttributeDecodeFailurePolicy? = nil
) = #externalMacro(module: "CoreDataEvolutionMacros", type: "AttributeMacro")
