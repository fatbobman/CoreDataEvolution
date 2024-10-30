//
//  Macros.swift
//
//
//  Created by Yang Xu on 2024/4/9.
//

import Foundation
import SwiftData

// MARK: - Core Data Macro

@attached(member, names: named(modelExecutor), named(modelContainer), named(init))
@attached(extension, conformances: NSModelActor)
public macro NSModelActor(disableGenerateInit: Bool = false) = #externalMacro(module: "CoreDataEvolutionMacros", type: "NSModelActorMacro")

@attached(member, names: named(modelExecutor), named(modelContainer), named(init))
@attached(extension, conformances: NSMainModelActor)
public macro NSMainModelActor(disableGenerateInit: Bool = false) = #externalMacro(module: "CoreDataEvolutionMacros", type: "NSMainModelActorMacro")
