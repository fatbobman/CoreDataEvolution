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

protocol AttributeAccessorBuilder {
  func makeGetter(from info: AttributeInfo) -> AccessorDeclSyntax
  func makeSetter(from info: AttributeInfo) -> AccessorDeclSyntax
}

enum AttributeAccessorBuilderFactory {
  static func makeBuilder(for storageMethod: ParsedAttributeStorageMethod)
    -> any AttributeAccessorBuilder
  {
    switch storageMethod {
    case .default:
      return DefaultAttributeAccessorBuilder()
    case .raw:
      return RawAttributeAccessorBuilder()
    case .codable:
      return CodableAttributeAccessorBuilder()
    case .transformed(let transformer):
      return TransformedAttributeAccessorBuilder(transformerType: transformer)
    case .composition:
      return CompositionAttributeAccessorBuilder()
    }
  }
}

func makeAccessors(from info: AttributeInfo) -> [AccessorDeclSyntax] {
  let builder = AttributeAccessorBuilderFactory.makeBuilder(for: info.storageMethod)
  return [builder.makeGetter(from: info), builder.makeSetter(from: info)]
}

struct DefaultAttributeAccessorBuilder: AttributeAccessorBuilder {
  func makeGetter(from info: AttributeInfo) -> AccessorDeclSyntax {
    let key = info.persistentName
    let property = info.propertyName
    let type = info.typeName
    let wrappedType = info.nonOptionalTypeName

    if let bridge = numberBridgeAccessor(forBaseType: info.baseTypeName) {
      if info.isOptional {
        return
          """
          get {
            guard let number = value(forKey: "\(raw: key)") as? NSNumber else { return nil }
            return number.\(raw: bridge)
          }
          """
      }
      return
        """
        get {
          guard let number = value(forKey: "\(raw: key)") as? NSNumber else {
            preconditionFailure("Missing required value for `\(raw: property)` (\(raw: key)).")
          }
          return number.\(raw: bridge)
        }
        """
    }

    if info.isOptional {
      return
        """
        get {
          value(forKey: "\(raw: key)") as? \(raw: wrappedType)
        }
        """
    }
    return
      """
      get {
        guard let value = value(forKey: "\(raw: key)") as? \(raw: type) else {
          preconditionFailure("Missing required value for `\(raw: property)` (\(raw: key)).")
        }
        return value
      }
      """
  }

  func makeSetter(from info: AttributeInfo) -> AccessorDeclSyntax {
    let key = info.persistentName

    if numberBridgeAccessor(forBaseType: info.baseTypeName) != nil {
      if info.baseTypeName == "Decimal" {
        if info.isOptional {
          return
            """
            set {
              if let newValue {
                setValue(NSDecimalNumber(decimal: newValue), forKey: "\(raw: key)")
              } else {
                setValue(nil, forKey: "\(raw: key)")
              }
            }
            """
        }
        return
          """
          set {
            setValue(NSDecimalNumber(decimal: newValue), forKey: "\(raw: key)")
          }
          """
      }
      if info.isOptional {
        return
          """
          set {
            if let newValue {
              setValue(NSNumber(value: newValue), forKey: "\(raw: key)")
            } else {
              setValue(nil, forKey: "\(raw: key)")
            }
          }
          """
      }
      return
        """
        set {
          setValue(NSNumber(value: newValue), forKey: "\(raw: key)")
        }
        """
    }
    return
      """
      set {
        setValue(newValue, forKey: "\(raw: key)")
      }
      """
  }
}

struct RawAttributeAccessorBuilder: AttributeAccessorBuilder {
  func makeGetter(from info: AttributeInfo) -> AccessorDeclSyntax {
    let key = info.persistentName
    let property = info.propertyName
    let type = info.typeName
    let wrappedType = info.nonOptionalTypeName
    let policy = info.decodeFailurePolicy ?? .fallbackToDefaultValue

    if info.isOptional, policy == .debugAssertNil {
      return
        """
        get {
          guard let rawValue = value(forKey: "\(raw: key)") as? \(raw: wrappedType).RawValue,
            let value = \(raw: wrappedType).init(rawValue: rawValue)
          else {
            assertionFailure("Invalid raw value for `\(raw: property)` (\(raw: key)).")
            return nil
          }
          return value
        }
        """
    }

    if info.isOptional, policy == .fallbackToDefaultValue {
      let fallback = info.defaultValueExpression ?? "nil"
      return
        """
        get {
          guard let rawValue = value(forKey: "\(raw: key)") as? \(raw: wrappedType).RawValue,
            let value = \(raw: wrappedType).init(rawValue: rawValue)
          else {
            return \(raw: fallback)
          }
          return value
        }
        """
    }

    if policy == .debugAssertNil {
      let fallback = info.defaultValueExpression ?? "nil"
      return
        """
        get {
          guard let rawValue = value(forKey: "\(raw: key)") as? \(raw: type).RawValue,
            let value = \(raw: type)(rawValue: rawValue)
          else {
            assertionFailure("Invalid raw value for `\(raw: property)` (\(raw: key)).")
            return \(raw: fallback)
          }
          return value
        }
        """
    }

    let fallback = info.defaultValueExpression ?? "nil"
    return
      """
      get {
        guard let rawValue = value(forKey: "\(raw: key)") as? \(raw: type).RawValue,
          let value = \(raw: type)(rawValue: rawValue)
        else {
          return \(raw: fallback)
        }
        return value
      }
      """
  }

  func makeSetter(from info: AttributeInfo) -> AccessorDeclSyntax {
    let key = info.persistentName
    if info.isOptional {
      return
        """
        set {
          setValue(newValue?.rawValue, forKey: "\(raw: key)")
        }
        """
    }
    return
      """
      set {
        setValue(newValue.rawValue, forKey: "\(raw: key)")
      }
      """
  }
}

struct CodableAttributeAccessorBuilder: AttributeAccessorBuilder {
  func makeGetter(from info: AttributeInfo) -> AccessorDeclSyntax {
    let key = info.persistentName
    let property = info.propertyName
    let type = info.typeName
    let wrappedType = info.nonOptionalTypeName
    let policy = info.decodeFailurePolicy ?? .fallbackToDefaultValue

    if info.isOptional, policy == .debugAssertNil {
      return
        """
        get {
          guard let data = value(forKey: "\(raw: key)") as? Data,
            let value = try? JSONDecoder().decode(\(raw: wrappedType).self, from: data)
          else {
            assertionFailure("Invalid codable payload for `\(raw: property)` (\(raw: key)).")
            return nil
          }
          return value
        }
        """
    }

    if info.isOptional, policy == .fallbackToDefaultValue {
      let fallback = info.defaultValueExpression ?? "nil"
      return
        """
        get {
          guard let data = value(forKey: "\(raw: key)") as? Data,
            let value = try? JSONDecoder().decode(\(raw: wrappedType).self, from: data)
          else {
            return \(raw: fallback)
          }
          return value
        }
        """
    }

    if policy == .debugAssertNil {
      let fallback = info.defaultValueExpression ?? "nil"
      return
        """
        get {
          guard let data = value(forKey: "\(raw: key)") as? Data,
            let value = try? JSONDecoder().decode(\(raw: type).self, from: data)
          else {
            assertionFailure("Invalid codable payload for `\(raw: property)` (\(raw: key)).")
            return \(raw: fallback)
          }
          return value
        }
        """
    }

    let fallback = info.defaultValueExpression ?? "nil"
    return
      """
      get {
        guard let data = value(forKey: "\(raw: key)") as? Data,
          let value = try? JSONDecoder().decode(\(raw: type).self, from: data)
        else {
          return \(raw: fallback)
        }
        return value
      }
      """
  }

  func makeSetter(from info: AttributeInfo) -> AccessorDeclSyntax {
    let key = info.persistentName
    let property = info.propertyName
    let type = info.typeName
    let wrappedType = info.nonOptionalTypeName
    let fallback = info.defaultValueExpression ?? "nil"
    let policy = info.decodeFailurePolicy ?? .fallbackToDefaultValue

    if info.isOptional, policy == .debugAssertNil {
      return
        """
        set {
          if let newValue {
            do {
              let data = try JSONEncoder().encode(newValue)
              setValue(data, forKey: "\(raw: key)")
            } catch {
              assertionFailure("Failed to encode codable value for `\(raw: property)` (\(raw: key)).")
              setValue(nil, forKey: "\(raw: key)")
            }
          } else {
            setValue(nil, forKey: "\(raw: key)")
          }
        }
        """
    }

    if info.isOptional, policy == .fallbackToDefaultValue {
      return
        """
        set {
          if let newValue {
            do {
              let data = try JSONEncoder().encode(newValue)
              setValue(data, forKey: "\(raw: key)")
            } catch {
              let fallback: \(raw: wrappedType)? = \(raw: fallback)
              if let fallback {
                let data = try? JSONEncoder().encode(fallback)
                setValue(data, forKey: "\(raw: key)")
              } else {
                setValue(nil, forKey: "\(raw: key)")
              }
            }
          } else {
            setValue(nil, forKey: "\(raw: key)")
          }
        }
        """
    }

    if policy == .debugAssertNil {
      return
        """
        set {
          do {
            let data = try JSONEncoder().encode(newValue)
            setValue(data, forKey: "\(raw: key)")
          } catch {
            assertionFailure("Failed to encode codable value for `\(raw: property)` (\(raw: key)).")
            setValue(nil, forKey: "\(raw: key)")
          }
        }
        """
    }

    return
      """
      set {
        do {
          let data = try JSONEncoder().encode(newValue)
          setValue(data, forKey: "\(raw: key)")
        } catch {
          let fallback: \(raw: type) = \(raw: fallback)
          let data = try? JSONEncoder().encode(fallback)
          setValue(data, forKey: "\(raw: key)")
        }
      }
      """
  }
}

struct TransformedAttributeAccessorBuilder: AttributeAccessorBuilder {
  let transformerType: String

  func makeGetter(from info: AttributeInfo) -> AccessorDeclSyntax {
    let key = info.persistentName
    let property = info.propertyName
    let type = info.typeName
    let wrappedType = info.nonOptionalTypeName
    let policy = info.decodeFailurePolicy ?? .fallbackToDefaultValue

    if info.isOptional, policy == .debugAssertNil {
      return
        """
        get {
          let transformer = \(raw: transformerType).init()
          let storedValue = value(forKey: "\(raw: key)")
          if let value = storedValue as? \(raw: wrappedType) {
            return value
          }
          guard let value = transformer.reverseTransformedValue(storedValue) as? \(raw: wrappedType) else {
            assertionFailure("Invalid transformed payload for `\(raw: property)` (\(raw: key)).")
            return nil
          }
          return value
        }
        """
    }

    if info.isOptional, policy == .fallbackToDefaultValue {
      let fallback = info.defaultValueExpression ?? "nil"
      return
        """
        get {
          let transformer = \(raw: transformerType).init()
          let storedValue = value(forKey: "\(raw: key)")
          if let value = storedValue as? \(raw: wrappedType) {
            return value
          }
          guard let value = transformer.reverseTransformedValue(storedValue) as? \(raw: wrappedType) else {
            return \(raw: fallback)
          }
          return value
        }
        """
    }

    if policy == .debugAssertNil {
      let fallback = info.defaultValueExpression ?? "nil"
      return
        """
        get {
          let transformer = \(raw: transformerType).init()
          let storedValue = value(forKey: "\(raw: key)")
          if let value = storedValue as? \(raw: type) {
            return value
          }
          guard let value = transformer.reverseTransformedValue(storedValue) as? \(raw: type) else {
            assertionFailure("Invalid transformed payload for `\(raw: property)` (\(raw: key)).")
            return \(raw: fallback)
          }
          return value
        }
        """
    }

    let fallback = info.defaultValueExpression ?? "nil"
    return
      """
      get {
        let transformer = \(raw: transformerType).init()
        let storedValue = value(forKey: "\(raw: key)")
        if let value = storedValue as? \(raw: type) {
          return value
        }
        guard let value = transformer.reverseTransformedValue(storedValue) as? \(raw: type) else {
          return \(raw: fallback)
        }
        return value
      }
      """
  }

  func makeSetter(from info: AttributeInfo) -> AccessorDeclSyntax {
    let key = info.persistentName
    let property = info.propertyName
    let type = info.typeName
    let wrappedType = info.nonOptionalTypeName
    let fallback = info.defaultValueExpression ?? "nil"
    let policy = info.decodeFailurePolicy ?? .fallbackToDefaultValue

    if info.isOptional, policy == .debugAssertNil {
      return
        """
        set {
          let transformer = \(raw: transformerType).init()
          if let newValue {
            guard let transformed = transformer.transformedValue(newValue) else {
              assertionFailure("Failed to transform value for `\(raw: property)` (\(raw: key)).")
              setValue(nil, forKey: "\(raw: key)")
              return
            }
            setValue(transformed, forKey: "\(raw: key)")
          } else {
            setValue(nil, forKey: "\(raw: key)")
          }
        }
        """
    }

    if info.isOptional, policy == .fallbackToDefaultValue {
      return
        """
        set {
          let transformer = \(raw: transformerType).init()
          if let newValue {
            if let transformed = transformer.transformedValue(newValue) {
              setValue(transformed, forKey: "\(raw: key)")
              return
            }

            let fallback: \(raw: wrappedType)? = \(raw: fallback)
            if let fallback, let transformed = transformer.transformedValue(fallback) {
              setValue(transformed, forKey: "\(raw: key)")
            } else {
              setValue(nil, forKey: "\(raw: key)")
            }
          } else {
            setValue(nil, forKey: "\(raw: key)")
          }
        }
        """
    }

    if policy == .debugAssertNil {
      return
        """
        set {
          let transformer = \(raw: transformerType).init()
          guard let transformed = transformer.transformedValue(newValue) else {
            assertionFailure("Failed to transform value for `\(raw: property)` (\(raw: key)).")
            setValue(nil, forKey: "\(raw: key)")
            return
          }
          setValue(transformed, forKey: "\(raw: key)")
        }
        """
    }

    return
      """
      set {
        let transformer = \(raw: transformerType).init()
        if let transformed = transformer.transformedValue(newValue) {
          setValue(transformed, forKey: "\(raw: key)")
          return
        }
        let fallback: \(raw: type) = \(raw: fallback)
        setValue(transformer.transformedValue(fallback), forKey: "\(raw: key)")
      }
      """
  }
}

struct CompositionAttributeAccessorBuilder: AttributeAccessorBuilder {
  func makeGetter(from info: AttributeInfo) -> AccessorDeclSyntax {
    let key = info.persistentName
    let property = info.propertyName
    let type = info.typeName
    let wrappedType = info.nonOptionalTypeName

    if info.isOptional {
      return
        """
        get {
          guard let dictionary = value(forKey: "\(raw: key)") as? [String: Any] else { return nil }
          return \(raw: wrappedType).__cdDecodeComposition(from: dictionary)
        }
        """
    }
    return
      """
      get {
        guard let dictionary = value(forKey: "\(raw: key)") as? [String: Any],
          let value = \(raw: type).__cdDecodeComposition(from: dictionary)
        else {
          preconditionFailure("Invalid composition payload for `\(raw: property)` (\(raw: key)).")
        }
        return value
      }
      """
  }

  func makeSetter(from info: AttributeInfo) -> AccessorDeclSyntax {
    let key = info.persistentName
    if info.isOptional {
      return
        """
        set {
          setValue(newValue?.__cdEncodeComposition, forKey: "\(raw: key)")
        }
        """
    }
    return
      """
      set {
        setValue(newValue.__cdEncodeComposition, forKey: "\(raw: key)")
      }
      """
  }
}
