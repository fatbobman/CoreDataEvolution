//
//  Macros.swift
//
//
//  Created by Yang Xu on 2024/4/9.
//

import CoreDataEvolution
import Foundation

@attached(member, names: named(modelExecutor), named(modelContainer), named(init))
@attached(extension, conformances: NSModelActor)
public macro NSModelActor() = #externalMacro(module: "CoreDataEvolutionMacrosPlugin", type: "NSModelActorMacro")

@attached(member, names: named(modelExecutor), named(modelContainer), named(init))
@attached(extension, conformances: NSMainModelActor)
public macro NSMainModelActor() = #externalMacro(module: "CoreDataEvolutionMacrosPlugin", type: "NSMainModelActorMacro")
