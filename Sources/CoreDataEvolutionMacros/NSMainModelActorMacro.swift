//
//  ------------------------------------------------
//  Original project: CoreDataEvolution
//  Created on 2024/9/20 by Fatbobman(东坡肘子)
//  X: @fatbobman
//  Mastodon: @fatbobman@mastodon.social
//  GitHub: @fatbobman
//  Blog: https://fatbobman.com
//  ------------------------------------------------
//  Copyright © 2024-present Fatbobman. All rights reserved.

import Foundation
import SwiftSyntax
/// Main-thread companion macro for Core Data types that should operate on `viewContext`.
///
/// Attach this macro to an `@MainActor` class to synthesize the stored container property and,
/// by default, a `modelContainer:` initializer.
///
///     @NSMainModelActor
///     @MainActor
///     final class DataHandler {}
///
///  will expand to
///
///     @NSMainModelActor
///     @MainActor
///     final class DataHandler{}
///       public let modelContainer: CoreData.NSPersistentContainer
///
///       public init(modelContainer: CoreData.NSPersistentContainer) {
///           self.modelContainer = modelContainer
///       }
///    extension DataHandler: CoreDataEvolution.NSMainModelActor {
///    }
import SwiftSyntaxMacros

public enum NSMainModelActorMacro {}
extension NSMainModelActorMacro: ExtensionMacro {
  public static func expansion(
    of _: SwiftSyntax.AttributeSyntax,
    attachedTo _: some SwiftSyntax.DeclGroupSyntax,
    providingExtensionsOf type: some SwiftSyntax.TypeSyntaxProtocol,
    conformingTo _: [SwiftSyntax.TypeSyntax],
    in _: some SwiftSyntaxMacros.MacroExpansionContext
  ) throws -> [SwiftSyntax.ExtensionDeclSyntax] {
    let decl: DeclSyntax =
      """
      extension \(type.trimmed): CoreDataEvolution.NSMainModelActor {}
      """

    guard let extensionDecl = decl.as(ExtensionDeclSyntax.self) else {
      return []
    }

    return [extensionDecl]
  }
}
extension NSMainModelActorMacro: MemberMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    conformingTo _: [TypeSyntax],
    in _: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    let generateInitializer = shouldGenerateInitializer(from: node)
    let accessModifier = witnessAccessModifierText(from: declaration)

    let decl: DeclSyntax =
      """
      \(raw: accessModifier)let modelContainer: CoreData.NSPersistentContainer
      """

    let initializer: DeclSyntax? =
      generateInitializer
      ? """
      \(raw: accessModifier)init(modelContainer: CoreData.NSPersistentContainer) {
        self.modelContainer = modelContainer
      }
      """ : nil
    return [decl] + (initializer.map { [$0] } ?? [])
  }
}
