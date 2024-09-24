//
//  NSModelActorMacro.swift
//
//
//  Created by Yang Xu on 2024/4/9.
//

import Foundation
import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// The ModelActor in SwiftData corresponding to the Core Data version.
/// An interface for providing mutually-exclusive access to the attributes of a conforming model.
///
///     @NSModelActor
///     actor DataHandler {}
///
///  will expand to
///
///     @NSModelActor
///     actor DataHandler{}
///       public nonisolated let modelExecutor: CoreDataEvolution.NSModelObjectContextExecutor
///       public nonisolated let modelContainer: CoreData.NSPersistentContainer
///
///       public init(container: CoreData.NSPersistentContainer, mode: ActorContextMode = .newBackground) {
///         let context: NSManagedObjectContext
///         context = container.newBackgroundContext()
///         modelExecutor = CoreDataEvolution.NSModelObjectContextExecutor(context: context)
///         modelContainer = container
///       }
///     extension DataHandler: CoreDataEvolution.NSModelActor {
///     }
public enum NSModelActorMacro {}

extension NSModelActorMacro: ExtensionMacro {
  public static func expansion(of _: SwiftSyntax.AttributeSyntax, attachedTo _: some SwiftSyntax.DeclGroupSyntax, providingExtensionsOf type: some SwiftSyntax.TypeSyntaxProtocol, conformingTo _: [SwiftSyntax.TypeSyntax], in _: some SwiftSyntaxMacros.MacroExpansionContext) throws -> [SwiftSyntax.ExtensionDeclSyntax] {
    let decl: DeclSyntax =
      """
      extension \(type.trimmed): CoreDataEvolution.NSModelActor {}
      """

    guard let extensionDecl = decl.as(ExtensionDeclSyntax.self) else {
      return []
    }

    return [extensionDecl]
  }
}

extension NSModelActorMacro: MemberMacro {
  public static func expansion(of _: AttributeSyntax, providingMembersOf _: some DeclGroupSyntax, conformingTo _: [TypeSyntax], in _: some MacroExpansionContext) throws -> [DeclSyntax] {
    [
      """
      public nonisolated let modelExecutor: CoreDataEvolution.NSModelObjectContextExecutor
      public nonisolated let modelContainer: CoreData.NSPersistentContainer

      public init(container: CoreData.NSPersistentContainer) {
          let context: NSManagedObjectContext
          context = container.newBackgroundContext()
          modelExecutor = CoreDataEvolution.NSModelObjectContextExecutor(context: context)
          modelContainer = container
      }
      """,
    ]
  }
}
