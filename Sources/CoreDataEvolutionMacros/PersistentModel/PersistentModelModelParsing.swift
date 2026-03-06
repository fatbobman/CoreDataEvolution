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

func validatePersistentModelStoredDeclarations(
  in classDecl: ClassDeclSyntax,
  context: some MacroExpansionContext
) -> Bool {
  var isValid = true

  for member in classDecl.memberBlock.members {
    guard let variable = member.decl.as(VariableDeclSyntax.self) else {
      continue
    }
    guard isPersistentModelInstanceStoredVariable(variable) else {
      continue
    }

    if variable.bindings.count > 1 {
      MacroDiagnosticReporter.error(
        "@PersistentModel does not support declaring multiple stored properties in one `var` declaration. Split them into separate declarations.",
        domain: persistentModelMacroDomain,
        in: context,
        node: variable
      )
      isValid = false
    }
  }

  return isValid
}

func analyzePersistentModelProperties(in classDecl: ClassDeclSyntax)
  -> PersistentModelAnalysis
{
  var properties: [PersistentModelPropertyKind] = []
  for storedBinding in persistentModelStoredBindings(in: classDecl) {
    if storedBinding.isIgnore {
      continue
    }

    let variable = storedBinding.variable
    let binding = storedBinding.binding
    let propertyName = storedBinding.propertyName
    let typeAnnotation = storedBinding.typeAnnotation
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
      let attribute = preferredAttributeForParsing(named: "Attribute", in: variable)
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
  return PersistentModelAnalysis(properties: properties)
}

func analyzePersistentModelInitProperties(in classDecl: ClassDeclSyntax)
  -> [PersistentModelInitProperty]
{
  var properties: [PersistentModelInitProperty] = []
  for storedBinding in persistentModelStoredBindings(in: classDecl) {
    let propertyName = storedBinding.propertyName
    let typeAnnotation = storedBinding.typeAnnotation
    let typeName = typeAnnotation.type.trimmedDescription

    if storedBinding.isIgnore {
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
  return properties
}

func validateInverseHints(
  in classDecl: ClassDeclSyntax,
  model: PersistentModelAnalysis,
  context: some MacroExpansionContext
) -> Bool {
  let relationshipsByName = Dictionary(
    uniqueKeysWithValues: model.relationships.map { ($0.propertyName, $0) })
  let propertyNodes = Dictionary(
    uniqueKeysWithValues: persistentModelStoredBindings(in: classDecl).map {
      ($0.propertyName, $0.variable)
    })

  var isValid = true

  for (propertyName, variable) in propertyNodes {
    guard let inverseAttribute = firstAttribute(named: "Inverse", in: variable) else {
      continue
    }

    if let binding = variable.bindings.first,
      let typeAnnotation = binding.typeAnnotation,
      isOptionalToManyRelationshipType(typeAnnotation.type)
    {
      // Optional to-many relationships are rejected earlier. Avoid stacking a second, less useful
      // "not a relationship" diagnostic on the same declaration.
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
    // Macro expansion only sees the current type declaration, so it can require explicit inverse
    // hints on this side but cannot enforce that the matching inverse property in another type is
    // also annotated. Tooling validation and runtime schema wiring cover the full graph later.
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
  guard variable.bindings.count == 1 else {
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

private func persistentModelStoredBindings(
  in classDecl: ClassDeclSyntax
) -> [PersistentModelStoredBinding] {
  // Keep one canonical stored-property view for all parsing passes so generated members, init
  // synthesis, and inverse validation cannot drift on filtering rules.
  classDecl.memberBlock.members.compactMap { member in
    guard let variable = member.decl.as(VariableDeclSyntax.self) else {
      return nil
    }
    guard isPersistentModelInstanceStoredVariable(variable) else {
      return nil
    }
    guard variable.bindings.count == 1, let binding = variable.bindings.first else {
      return nil
    }
    guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
      return nil
    }
    guard let typeAnnotation = binding.typeAnnotation else {
      return nil
    }
    guard binding.accessorBlock == nil else {
      return nil
    }

    return PersistentModelStoredBinding(
      variable: variable,
      binding: binding,
      propertyName: pattern.identifier.text,
      typeAnnotation: typeAnnotation,
      isIgnore: hasMarkerAttribute("Ignore", in: variable)
    )
  }
}

private func isPersistentModelInstanceStoredVariable(_ variable: VariableDeclSyntax) -> Bool {
  guard variable.bindingSpecifier.tokenKind == .keyword(.var) else {
    return false
  }
  if variable.modifiers.contains(where: { $0.name.text == "static" || $0.name.text == "class" }) {
    return false
  }
  if variable.modifiers.contains(where: { $0.name.text == "lazy" }) {
    return false
  }
  return true
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
