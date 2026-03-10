/// Shared helpers for generating CDRuntimePrimitiveAttributeType and default-value expressions,
/// used by both @PersistentModel and @Composition macro member generation.

func runtimePrimitiveTypeExpression(typeName: String) -> String {
  switch typeName {
  case "String":
    return ".string"
  case "Bool":
    return ".bool"
  case "Int16":
    return ".int16"
  case "Int32":
    return ".int32"
  case "Int", "Int64":
    return ".int64"
  case "Float":
    return ".float"
  case "Double":
    return ".double"
  case "Decimal":
    return ".decimal"
  case "Date":
    return ".date"
  case "Data":
    return ".data"
  case "UUID":
    return ".uuid"
  case "URL":
    return ".url"
  default:
    return """
      ({
        #warning("Unsupported runtime primitive type '\(typeName)'. Falling back to .string.")
        return CoreDataEvolution.CDRuntimePrimitiveAttributeType.string
      }())
      """
  }
}

func runtimeDefaultValueExpression(_ expression: String?) -> String {
  if let expression {
    return "\"\(escapeStringLiteral(expression))\""
  }
  return "nil"
}
