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

public enum PersistentModelMacro {}

extension PersistentModelMacro: ExtensionMacro {
  public static func expansion(
    of _: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo _: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    guard let classDecl = declaration.as(ClassDeclSyntax.self) else {
      return []
    }
    guard hasExplicitObjCClassName(on: classDecl) else {
      return []
    }

    let decl: DeclSyntax =
      """
      extension \(type.trimmed): CoreDataEvolution.PersistentEntity {}
      """
    guard let ext = decl.as(ExtensionDeclSyntax.self) else {
      MacroDiagnosticReporter.error(
        "@PersistentModel failed to generate extension conformance.",
        domain: persistentModelMacroDomain,
        in: context,
        node: declaration
      )
      return []
    }
    return [ext]
  }
}

extension PersistentModelMacro: MemberAttributeMacro {
  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingAttributesFor member: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [AttributeSyntax] {
    guard let classDecl = declaration.as(ClassDeclSyntax.self) else {
      return []
    }
    guard hasExplicitObjCClassName(on: classDecl) else {
      return []
    }
    guard let variable = member.as(VariableDeclSyntax.self) else {
      return []
    }

    let arguments = parsePersistentModelArguments(
      from: node,
      context: context,
      emitDiagnostics: false
    )
    guard
      let attribute = autoAttachedAttribute(
        for: variable,
        relationshipSetterPolicy: arguments?.relationshipSetterPolicy ?? .none
      )
    else {
      return []
    }
    return [attribute]
  }
}

extension PersistentModelMacro: MemberMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    conformingTo _: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard let classDecl = declaration.as(ClassDeclSyntax.self) else {
      MacroDiagnosticReporter.error(
        "@PersistentModel can only be attached to a class declaration.",
        domain: persistentModelMacroDomain,
        in: context,
        node: declaration
      )
      return []
    }

    guard classDecl.inheritsFromNSManagedObject else {
      MacroDiagnosticReporter.error(
        "@PersistentModel type must inherit from NSManagedObject.",
        domain: persistentModelMacroDomain,
        in: context,
        node: classDecl
      )
      return []
    }
    guard hasExplicitObjCClassName(on: classDecl) else {
      MacroDiagnosticReporter.error(
        "@PersistentModel type must declare @objc(ClassName) explicitly. Current Swift macro roles cannot inject type attributes automatically.",
        domain: persistentModelMacroDomain,
        in: context,
        node: classDecl
      )
      return []
    }

    guard
      let arguments = parsePersistentModelArguments(
        from: node,
        context: context
      )
    else {
      return []
    }

    let accessModifier = accessModifierText(from: declaration)
    let modelTypeName = classDecl.name.text
    let model = analyzePersistentModelProperties(in: classDecl)
    let initProperties = analyzePersistentModelInitProperties(in: classDecl)

    var members: [DeclSyntax] = []
    members.append(makeKeysDecl(accessModifier: accessModifier, model: model))
    members.append(
      makePathsDecl(
        accessModifier: accessModifier,
        modelTypeName: modelTypeName,
        model: model
      )
    )
    members.append(
      makePathRootDecl(
        accessModifier: accessModifier,
        modelTypeName: modelTypeName,
        model: model
      )
    )
    members.append(makePathEntryDecl(accessModifier: accessModifier))
    members.append(
      makeFieldTableDecl(
        accessModifier: accessModifier,
        modelTypeName: modelTypeName,
        model: model
      )
    )

    if let initDecl = makeInitDecl(
      accessModifier: accessModifier,
      properties: initProperties,
      generateInit: arguments.generateInit
    ) {
      members.append(initDecl)
    }

    members += makeToManyHelpers(
      accessModifier: accessModifier,
      model: model,
      setterPolicy: arguments.relationshipSetterPolicy,
      countPolicy: arguments.relationshipCountPolicy
    )
    return members
  }
}
