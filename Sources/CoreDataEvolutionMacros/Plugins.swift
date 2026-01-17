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
  ]
}
