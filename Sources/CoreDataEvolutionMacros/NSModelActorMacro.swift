//
//  ------------------------------------------------
//  Original project: CoreDataEvolution
//  Created on 2024/4/9 by Fatbobman(东坡肘子)
//  X: @fatbobman
//  Mastodon: @fatbobman@mastodon.social
//  GitHub: @fatbobman
//  Blog: https://fatbobman.com
//  ------------------------------------------------
//  Copyright © 2024-present Fatbobman. All rights reserved.

import Foundation
import SwiftSyntax
import SwiftSyntaxMacros

/// Expands `@NSModelActor` into the stored properties and conformance required by the runtime
/// `NSModelActor` protocol.
public enum NSModelActorMacro {}
extension NSModelActorMacro: ExtensionMacro {
  public static func expansion(
    of _: SwiftSyntax.AttributeSyntax,
    attachedTo _: some SwiftSyntax.DeclGroupSyntax,
    providingExtensionsOf type: some SwiftSyntax.TypeSyntaxProtocol,
    conformingTo _: [SwiftSyntax.TypeSyntax],
    in _: some SwiftSyntaxMacros.MacroExpansionContext
  ) throws -> [SwiftSyntax.ExtensionDeclSyntax] {
    guard
      let extensionDecl = makeModelActorConformanceExtension(
        for: type,
        flavor: .backgroundActor
      )
    else {
      return []
    }

    return [extensionDecl]
  }
}
extension NSModelActorMacro: MemberMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    conformingTo _: [TypeSyntax],
    in _: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    let generateInitializer = shouldGenerateInitializer(from: node)
    let accessModifier = witnessAccessModifierText(from: declaration)
    return makeModelActorMemberDecls(
      flavor: .backgroundActor,
      accessModifier: accessModifier,
      generateInitializer: generateInitializer
    )
  }
}
