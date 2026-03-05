//
//  Macros.swift
//
//
//  Created by Yang Xu on 2024/4/9.
//

import Foundation

// MARK: - Core Data Macro

public enum AttributeStorageMethod {
  case `default`
  case raw
  case codable
  case transformed(ValueTransformer.Type)
  case composition
}

public enum AttributeDecodeFailurePolicy {
  case fallbackToDefaultValue
  case debugAssertNil
}

public enum RelationshipGenerationPolicy {
  case none
  case warning
  case plain
}

@attached(member, names: named(modelExecutor), named(modelContainer), named(init))
@attached(extension, conformances: NSModelActor)
public macro NSModelActor(disableGenerateInit: Bool = false) =
  #externalMacro(module: "CoreDataEvolutionMacros", type: "NSModelActorMacro")

@attached(member, names: named(modelExecutor), named(modelContainer), named(init))
@attached(extension, conformances: NSMainModelActor)
public macro NSMainModelActor(disableGenerateInit: Bool = false) =
  #externalMacro(module: "CoreDataEvolutionMacros", type: "NSMainModelActorMacro")

@attached(
  member,
  names: named(__cdCompositionFieldTable), named(__cdDecodeComposition),
  named(__cdEncodeComposition)
)
@attached(extension, conformances: CDCompositionPathProviding, CDCompositionValueCodable)
public macro Composition() =
  #externalMacro(module: "CoreDataEvolutionMacros", type: "CompositionMacro")

@attached(peer)
public macro Ignore() =
  #externalMacro(module: "CoreDataEvolutionMacros", type: "IgnoreMacro")

@attached(accessor)
@attached(peer, names: arbitrary)
public macro _CDRelationship(
  setterPolicy: RelationshipGenerationPolicy = .none,
  _fromPersistentModel: Bool = false
) = #externalMacro(module: "CoreDataEvolutionMacros", type: "RelationshipMacro")

@attached(memberAttribute)
@attached(member, names: arbitrary)
@attached(extension, conformances: PersistentEntity)
public macro PersistentModel(
  generateInit: Bool = false,
  relationshipSetterPolicy: RelationshipGenerationPolicy = .none,
  relationshipCountPolicy: RelationshipGenerationPolicy = .none
) = #externalMacro(module: "CoreDataEvolutionMacros", type: "PersistentModelMacro")

@attached(accessor)
@attached(peer, names: arbitrary)
public macro Attribute(
  originalName: String? = nil,
  storageMethod: AttributeStorageMethod? = nil,
  decodeFailurePolicy: AttributeDecodeFailurePolicy? = nil
) = #externalMacro(module: "CoreDataEvolutionMacros", type: "AttributeMacro")
