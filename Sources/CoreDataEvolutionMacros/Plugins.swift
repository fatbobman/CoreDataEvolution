//
//  Plugins.swift
//
//
//  Created by Yang Xu on 2024/4/9.
//

import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct CoreDataEvolutionMacrosPlugin: CompilerPlugin {
  let providingMacros: [Macro.Type] = [
    NSModelActorMacro.self,
    NSMainModelActorMacro.self,
    PersistentModelMacro.self,
    AttributeMacro.self,
    CompositionMacro.self,
    CompositionFieldMacro.self,
    IgnoreMacro.self,
    PublicRelationshipMacro.self,
    RelationshipMacro.self,
  ]
}
