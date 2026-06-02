//
//  ------------------------------------------------
//  Original project: CoreDataEvolution
//  Created on 2026/5/31 by Fatbobman(东坡肘子)
//  X: @fatbobman
//  Mastodon: @fatbobman@mastodon.social
//  GitHub: @fatbobman
//  Blog: https://fatbobman.com
//  ------------------------------------------------
//  Copyright © 2024-present Fatbobman. All rights reserved.

import SwiftSyntax
import SwiftSyntaxMacros

let cdeObservationAvailability =
  "@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)"

#if compiler(>=6.2)
  let isCDEObservationCompilerSupported = true
#else
  let isCDEObservationCompilerSupported = false
#endif

func observationMode(in variable: VariableDeclSyntax) -> ParsedPersistentModelObservationMode {
  guard let attribute = firstAttribute(named: "_CDObserved", in: variable) else {
    return .none
  }
  guard let list = attribute.arguments?.as(LabeledExprListSyntax.self) else {
    return .none
  }
  for argument in list where argument.label == nil {
    if argument.expression.trimmedDescription.replacingOccurrences(of: " ", with: "")
      == ".mainActor"
    {
      return .mainActor
    }
  }
  return .none
}

func observationMode(
  in variable: VariableDeclSyntax,
  context: some MacroExpansionContext
) -> ParsedPersistentModelObservationMode {
  let markerMode = observationMode(in: variable)
  if markerMode != .none {
    return markerMode
  }

  return enclosingPersistentModelObservationMode(in: context)
}

private func enclosingPersistentModelObservationMode(
  in context: some MacroExpansionContext
) -> ParsedPersistentModelObservationMode {
  // In the real compiler pipeline, accessor macros cannot rely on member-attribute markers
  // being visible, so observed accessors also read the enclosing @PersistentModel contract.
  for syntax in context.lexicalContext {
    guard let classDecl = syntax.as(ClassDeclSyntax.self),
      let persistentModel = firstAttribute(named: "PersistentModel", in: classDecl.attributes),
      let arguments = parsePersistentModelArguments(
        from: persistentModel,
        context: context,
        emitDiagnostics: false
      )
    else {
      continue
    }

    return arguments.observation
  }

  return .none
}

private func firstAttribute(
  named name: String,
  in attributes: AttributeListSyntax
) -> AttributeSyntax? {
  attributes
    .compactMap { $0.as(AttributeSyntax.self) }
    .first { attributeName(of: $0) == name }
}

func makeObservationTrackedGetter(
  _ getter: AccessorDeclSyntax,
  propertyName: String,
  observation: ParsedPersistentModelObservationMode
) -> AccessorDeclSyntax {
  guard isCDEObservationCompilerSupported, observation == .mainActor, var body = getter.body else {
    return getter
  }

  var observedGetter = getter
  let availabilityAttribute: AttributeListSyntax.Element = .attribute(
    AttributeSyntax(stringLiteral: cdeObservationAvailability)
  )
  observedGetter.attributes = AttributeListSyntax(
    [availabilityAttribute] + Array(observedGetter.attributes)
  )

  let accessItem: CodeBlockItemSyntax =
    """
    CoreDataEvolution._cdeObservationAccess(
      self,
      \\.\(raw: propertyName),
      registrar: _$observationRegistrar
    )
    """
  // Once access() is prepended, expression-style getter bodies need an explicit return.
  let originalStatements = body.statements.description
  let returnItem: CodeBlockItemSyntax =
    """
    return {
    \(raw: originalStatements)
    }()
    """
  body.statements = CodeBlockItemListSyntax([accessItem, returnItem])
  observedGetter.body = body
  return observedGetter
}
