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

func analyzePersistentModelProperties(in classDecl: ClassDeclSyntax)
  -> PersistentModelAnalysis
{
  var properties: [PersistentModelPropertyKind] = []
  for member in classDecl.memberBlock.members {
    guard let variable = member.decl.as(VariableDeclSyntax.self) else {
      continue
    }
    if variable.bindingSpecifier.tokenKind != .keyword(.var) {
      continue
    }
    if variable.modifiers.contains(where: { $0.name.text == "static" || $0.name.text == "class" }) {
      continue
    }
    if variable.modifiers.contains(where: { $0.name.text == "lazy" }) {
      continue
    }
    if hasMarkerAttribute("Ignore", in: variable) {
      continue
    }

    for binding in variable.bindings {
      guard binding.accessorBlock == nil else {
        continue
      }
      guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self) else {
        continue
      }
      guard let typeAnnotation = binding.typeAnnotation else {
        continue
      }

      let propertyName = identifier.identifier.text
      let typeName = typeAnnotation.type.trimmedDescription
      let nonOptionalTypeName = attributeOptionalWrappedTypeName(typeAnnotation.type) ?? typeName
      let isOptional = attributeOptionalWrappedTypeName(typeAnnotation.type) != nil
      let defaultValueExpression = binding.initializer?.value.trimmedDescription
      let inverseArguments = firstAttribute(named: "Inverse", in: variable).flatMap(
        parseInverseDeclArguments)

      if isOptionalToManyRelationshipType(typeAnnotation.type) {
        continue
      }

      if hasMarkerAttribute("Attribute", in: variable),
        let attribute = firstAttribute(named: "Attribute", in: variable)
      {
        let parsed = parseAttributeDeclArguments(attribute)
        properties.append(
          .attribute(
            PersistentAttributeProperty(
              propertyName: propertyName,
              typeName: typeName,
              nonOptionalTypeName: nonOptionalTypeName,
              persistentName: parsed.originalName ?? propertyName,
              isOptional: isOptional,
              storageMethod: parsed.storageMethod ?? .default,
              defaultValueExpression: defaultValueExpression
                ?? optionalFallbackDefault(type: typeAnnotation.type),
              isUnique: parsed.traits.contains(.unique),
              isTransient: parsed.traits.contains(.transient)
            )
          )
        )
        continue
      }

      if let relationship = parseRelationshipProperty(
        propertyName: propertyName,
        type: typeAnnotation.type,
        inverseArguments: inverseArguments
      ) {
        properties.append(.relationship(relationship))
        continue
      }

      properties.append(
        .attribute(
          PersistentAttributeProperty(
            propertyName: propertyName,
            typeName: typeName,
            nonOptionalTypeName: nonOptionalTypeName,
            persistentName: propertyName,
            isOptional: isOptional,
            storageMethod: .default,
            defaultValueExpression: defaultValueExpression
              ?? optionalFallbackDefault(type: typeAnnotation.type),
            isUnique: false,
            isTransient: false
          )
        )
      )
    }
  }
  return PersistentModelAnalysis(properties: properties)
}

func analyzePersistentModelInitProperties(in classDecl: ClassDeclSyntax)
  -> [PersistentModelInitProperty]
{
  var properties: [PersistentModelInitProperty] = []
  for member in classDecl.memberBlock.members {
    guard let variable = member.decl.as(VariableDeclSyntax.self) else {
      continue
    }
    let isIgnoreProperty = hasMarkerAttribute("Ignore", in: variable)
    if variable.bindingSpecifier.tokenKind != .keyword(.var) {
      continue
    }
    if variable.modifiers.contains(where: { $0.name.text == "static" || $0.name.text == "class" }) {
      continue
    }
    if variable.modifiers.contains(where: { $0.name.text == "lazy" }) {
      continue
    }

    for binding in variable.bindings {
      guard binding.accessorBlock == nil else {
        continue
      }
      guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self) else {
        continue
      }
      guard let typeAnnotation = binding.typeAnnotation else {
        continue
      }

      let propertyName = identifier.identifier.text
      let typeName = typeAnnotation.type.trimmedDescription

      if isIgnoreProperty {
        properties.append(
          PersistentModelInitProperty(
            propertyName: propertyName,
            typeName: typeName
          )
        )
        continue
      }

      if isOptionalToManyRelationshipType(typeAnnotation.type) {
        continue
      }
      if parseRelationshipProperty(
        propertyName: propertyName,
        type: typeAnnotation.type,
        inverseArguments: nil
      ) != nil {
        continue
      }
      if isLikelyMissingOptionalToOneRelationship(typeAnnotation.type) {
        continue
      }

      properties.append(
        PersistentModelInitProperty(
          propertyName: propertyName,
          typeName: typeName
        )
      )
    }
  }
  return properties
}

func validateInverseHints(
  in classDecl: ClassDeclSyntax,
  model: PersistentModelAnalysis,
  context: some MacroExpansionContext
) -> Bool {
  let relationshipsByName = Dictionary(
    uniqueKeysWithValues: model.relationships.map { ($0.propertyName, $0) })
  var propertyNodes: [String: VariableDeclSyntax] = [:]

  for member in classDecl.memberBlock.members {
    guard let variable = member.decl.as(VariableDeclSyntax.self),
      variable.bindings.count == 1,
      let binding = variable.bindings.first,
      let identifier = binding.pattern.as(IdentifierPatternSyntax.self)
    else {
      continue
    }
    propertyNodes[identifier.identifier.text] = variable
  }

  var isValid = true

  for (propertyName, variable) in propertyNodes {
    guard let inverseAttribute = firstAttribute(named: "Inverse", in: variable) else {
      continue
    }
    guard let relationship = relationshipsByName[propertyName] else {
      MacroDiagnosticReporter.error(
        "@Inverse can only be attached to relationship properties.",
        domain: persistentModelMacroDomain,
        in: context,
        node: variable
      )
      isValid = false
      continue
    }
    guard let inverseArguments = parseInverseDeclArguments(inverseAttribute) else {
      continue
    }
    guard typeNamesReferToSameEntity(inverseArguments.targetTypeName, relationship.targetTypeName)
    else {
      MacroDiagnosticReporter.error(
        """
        @Inverse for '\(propertyName)' must target '\(relationship.targetTypeName)'. \
        Found '\(inverseArguments.targetTypeName)'.
        """,
        domain: persistentModelMacroDomain,
        in: context,
        node: inverseAttribute
      )
      isValid = false
      continue
    }
  }

  let groupedRelationships = Dictionary(grouping: model.relationships) {
    $0.targetTypeName.split(separator: ".").last.map(String.init) ?? $0.targetTypeName
  }

  for relationships in groupedRelationships.values where relationships.count > 1 {
    for relationship in relationships where relationship.inverseName == nil {
      let message =
        """
        Relationships from '\(classDecl.name.text)' to '\(relationship.targetTypeName)' are \
        ambiguous. Add @Inverse(\(relationship.targetTypeName).self, "property") to '\(relationship.propertyName)' and the matching inverse relationship.
        """
      if let propertyNode = propertyNodes[relationship.propertyName] {
        MacroDiagnosticReporter.error(
          message,
          domain: persistentModelMacroDomain,
          in: context,
          node: propertyNode
        )
      } else {
        MacroDiagnosticReporter.error(
          message,
          domain: persistentModelMacroDomain,
          in: context,
          node: classDecl
        )
      }
      isValid = false
    }
  }

  return isValid
}

func autoAttachedAttribute(
  for variable: VariableDeclSyntax,
  relationshipSetterPolicy: ParsedRelationshipGenerationPolicy
) -> AttributeSyntax? {
  guard variable.bindingSpecifier.tokenKind == .keyword(.var) else {
    return nil
  }
  if hasMarkerAttribute("Ignore", in: variable)
    || hasMarkerAttribute("Attribute", in: variable)
    || hasMarkerAttribute("_CDRelationship", in: variable)
  {
    return nil
  }
  if variable.modifiers.contains(where: { $0.name.text == "static" || $0.name.text == "class" }) {
    return nil
  }
  if variable.modifiers.contains(where: { $0.name.text == "lazy" }) {
    return nil
  }

  for binding in variable.bindings {
    guard binding.accessorBlock == nil else {
      return nil
    }
    guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
      return nil
    }
    guard let typeAnnotation = binding.typeAnnotation else {
      return nil
    }
    if isOptionalToManyRelationshipType(typeAnnotation.type) {
      return "@_CDRelationship(_fromPersistentModel: true)"
    }
    if let relationship = parseRelationshipProperty(
      propertyName: pattern.identifier.text,
      type: typeAnnotation.type,
      inverseArguments: nil
    ) {
      if relationship.kind == .toManySet {
        return
          "@_CDRelationship(setterPolicy: \(raw: relationshipSetterPolicyExpression(relationshipSetterPolicy)), _fromPersistentModel: true)"
      } else {
        return "@_CDRelationship(_fromPersistentModel: true)"
      }
    }
    if isLikelyMissingOptionalToOneRelationship(typeAnnotation.type) {
      return "@_CDRelationship(_fromPersistentModel: true)"
    }
  }

  return "@Attribute"
}

private func relationshipSetterPolicyExpression(_ policy: ParsedRelationshipGenerationPolicy)
  -> String
{
  switch policy {
  case .none:
    return ".none"
  case .warning:
    return ".warning"
  case .plain:
    return ".plain"
  }
}

private func parseRelationshipProperty(
  propertyName: String,
  type: TypeSyntax,
  inverseArguments: ParsedInverseDeclArguments?
) -> PersistentRelationshipProperty? {
  if let element = setElementTypeName(type) {
    return PersistentRelationshipProperty(
      propertyName: propertyName,
      targetTypeName: element,
      inverseName: inverseArguments?.inversePropertyName,
      kind: .toManySet
    )
  }
  if let element = arrayElementTypeName(type) {
    return PersistentRelationshipProperty(
      propertyName: propertyName,
      targetTypeName: element,
      inverseName: inverseArguments?.inversePropertyName,
      kind: .toManyArray
    )
  }
  if let wrappedType = optionalWrappedTypeSyntax(type) {
    if setElementTypeName(wrappedType) != nil || arrayElementTypeName(wrappedType) != nil {
      return nil
    }
    let wrapped = wrappedType.trimmedDescription
    let base = normalizedBaseTypeName(wrappedType) ?? wrapped
    if coreDataPrimitiveTypeNames.contains(base) == false {
      return PersistentRelationshipProperty(
        propertyName: propertyName,
        targetTypeName: wrapped,
        inverseName: inverseArguments?.inversePropertyName,
        kind: .toOne
      )
    }
  }
  return nil
}

func isOptionalToManyRelationshipType(_ type: TypeSyntax) -> Bool {
  guard let wrappedType = optionalWrappedTypeSyntax(type) else {
    return false
  }
  return setElementTypeName(wrappedType) != nil || arrayElementTypeName(wrappedType) != nil
}

private func isLikelyMissingOptionalToOneRelationship(_ type: TypeSyntax) -> Bool {
  if optionalWrappedTypeSyntax(type) != nil {
    return false
  }
  if setElementTypeName(type) != nil || arrayElementTypeName(type) != nil {
    return false
  }
  let base = normalizedBaseTypeName(type) ?? type.trimmedDescription
  return coreDataPrimitiveTypeNames.contains(base) == false
}

private struct ParsedAttributeDeclArguments {
  let traits: [ParsedAttributeTrait]
  let originalName: String?
  let storageMethod: ParsedAttributeStorageMethod?
}

private func parseAttributeDeclArguments(_ attribute: AttributeSyntax)
  -> ParsedAttributeDeclArguments
{
  guard let list = attribute.arguments?.as(LabeledExprListSyntax.self) else {
    return ParsedAttributeDeclArguments(traits: [], originalName: nil, storageMethod: nil)
  }
  var traits: [ParsedAttributeTrait] = []
  var originalName: String?
  var storageMethod: ParsedAttributeStorageMethod?

  for argument in list {
    guard let label = argument.label?.text else {
      if let trait = parseAttributeTraitShallow(argument.expression.trimmedDescription) {
        if traits.contains(trait) == false {
          traits.append(trait)
        }
      }
      continue
    }
    switch label {
    case "originalName":
      if let literal = argument.expression.as(StringLiteralExprSyntax.self),
        literal.segments.count == 1,
        let segment = literal.segments.first?.as(StringSegmentSyntax.self)
      {
        originalName = segment.content.text
      }
    case "storageMethod":
      storageMethod = parseAttributeStorageMethod(
        from: argument.expression.trimmedDescription.replacingOccurrences(of: " ", with: "")
      )
    default:
      continue
    }
  }

  return ParsedAttributeDeclArguments(
    traits: traits,
    originalName: originalName,
    storageMethod: storageMethod
  )
}

private func parseAttributeTraitShallow(_ rawText: String) -> ParsedAttributeTrait? {
  let raw = rawText.replacingOccurrences(of: " ", with: "")
  if raw == ".unique"
    || raw == "AttributeTrait.unique"
    || raw == "CoreDataEvolution.AttributeTrait.unique"
  {
    return .unique
  }
  if raw == ".transient"
    || raw == "AttributeTrait.transient"
    || raw == "CoreDataEvolution.AttributeTrait.transient"
  {
    return .transient
  }
  return nil
}

private func parseAttributeStorageMethod(from raw: String) -> ParsedAttributeStorageMethod? {
  if raw == ".default"
    || raw == "AttributeStorageMethod.default"
    || raw == "CoreDataEvolution.AttributeStorageMethod.default"
  {
    return .default
  }
  if raw == ".raw"
    || raw == "AttributeStorageMethod.raw"
    || raw == "CoreDataEvolution.AttributeStorageMethod.raw"
  {
    return .raw
  }
  if raw == ".codable"
    || raw == "AttributeStorageMethod.codable"
    || raw == "CoreDataEvolution.AttributeStorageMethod.codable"
  {
    return .codable
  }
  if raw == ".composition"
    || raw == "AttributeStorageMethod.composition"
    || raw == "CoreDataEvolution.AttributeStorageMethod.composition"
  {
    return .composition
  }
  if raw.hasPrefix(".transformed(")
    || raw.hasPrefix("AttributeStorageMethod.transformed(")
    || raw.hasPrefix("CoreDataEvolution.AttributeStorageMethod.transformed(")
  {
    return .transformed("ValueTransformer")
  }
  return nil
}
