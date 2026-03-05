//
//  ------------------------------------------------
//  Original project: CoreDataEvolution
//  Created on 2026/3/5 by Fatbobman(东坡肘子)
//  X: @fatbobman
//  Mastodon: @fatbobman@mastodon.social
//  GitHub: @fatbobman
//  Blog: https://fatbobman.com
//  ------------------------------------------------
//  Copyright © 2024-present Fatbobman. All rights reserved.

import SwiftSyntax
import SwiftSyntaxMacros

public enum AttributeMacro {}

extension AttributeMacro: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard
      let info = buildAttributeInfo(
        from: node,
        declaration: declaration,
        emitDiagnostics: true,
        context: context
      )
    else {
      return []
    }
    return makeAttributeValidationPeers(from: info)
  }
}

extension AttributeMacro: AccessorMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingAccessorsOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [AccessorDeclSyntax] {
    guard
      let info = buildAttributeInfo(
        from: node,
        declaration: declaration,
        emitDiagnostics: false,
        context: context
      )
    else {
      return []
    }
    return makeAccessors(from: info)
  }
}
