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

let cdeObservationAvailability =
  "@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)"

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

func makeObservationTrackedGetter(
  _ getter: AccessorDeclSyntax,
  propertyName: String,
  observation: ParsedPersistentModelObservationMode
) -> AccessorDeclSyntax {
  guard observation == .mainActor, var body = getter.body else {
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
  body.statements = CodeBlockItemListSyntax([accessItem] + Array(body.statements))
  observedGetter.body = body
  return observedGetter
}
