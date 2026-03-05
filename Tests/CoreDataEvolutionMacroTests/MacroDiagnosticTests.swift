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

import Testing

@Suite("Macro Diagnostics")
struct MacroDiagnosticTests {
  @Test("PersistentModel rejects non-class declaration")
  func persistentModelRejectsNonClassDeclaration() throws {
    let result = try MacroTestSupport.expand(
      source: """
        @PersistentModel
        struct S {}
        """
    )
    #expect(
      result.diagnostics.contains { $0.contains("can only be attached to a class declaration") })
  }

  @Test("PersistentModel rejects unknown argument")
  func persistentModelRejectsUnknownArgument() throws {
    let result = try MacroTestSupport.expand(
      source: """
        import CoreData
        @PersistentModel(relationshipGetterPolicy: .plain)
        final class S: NSManagedObject {}
        """
    )
    #expect(
      result.diagnostics.contains {
        $0.contains("unknown argument label `relationshipGetterPolicy`")
      })
  }

  @Test("PersistentModel auto-applies Attribute to unannotated persisted var")
  func persistentModelAutoAppliesAttributeToUnannotatedPersistedVar() throws {
    let result = try MacroTestSupport.expand(
      source: """
        import CoreData
        import CoreDataEvolution
        @PersistentModel
        final class Item: NSManagedObject {
          var title: String = ""
        }
        """
    )
    #expect(result.diagnostics.isEmpty)
    #expect(result.expandedSource.contains("value(forKey: \"title\") as? String"))
    #expect(result.expandedSource.contains("setValue(newValue, forKey: \"title\")"))
  }

  @Test("_CDRelationship rejects manual use outside PersistentModel")
  func relationshipRejectsManualUseOutsidePersistentModel() throws {
    let result = try MacroTestSupport.expand(
      source: """
        import CoreData
        import CoreDataEvolution
        final class Item: NSManagedObject {
          @_CDRelationship
          var category: Category?
        }
        """
    )
    #expect(
      result.diagnostics.contains {
        $0.contains("can only be used inside @PersistentModel types")
      })
  }

  @Test("Attribute default accepts primitive type")
  func attributeDefaultAcceptsPrimitive() throws {
    let result = try MacroTestSupport.expand(
      source: """
        struct S {
          @Attribute
          var count: Int? = nil
        }
        """
    )
    #expect(result.diagnostics.isEmpty)
  }

  @Test("Attribute default accepts Decimal type")
  func attributeDefaultAcceptsDecimal() throws {
    let result = try MacroTestSupport.expand(
      source: """
        import Foundation
        struct S {
          @Attribute
          var amount: Decimal? = nil
        }
        """
    )
    #expect(result.diagnostics.isEmpty)
  }

  @Test("Attribute explicit default rejects non-primitive type")
  func attributeExplicitDefaultRejectsNonPrimitive() throws {
    let result = try MacroTestSupport.expand(
      source: """
        struct MyConfig {}
        struct S {
          @Attribute(storageMethod: .default)
          var config: MyConfig? = nil
        }
        """
    )
    #expect(
      result.diagnostics.contains { $0.contains("`.default` storage only supports primitive") })
  }

  @Test("Attribute implicit default rejects non-primitive type")
  func attributeImplicitDefaultRejectsNonPrimitive() throws {
    let result = try MacroTestSupport.expand(
      source: """
        struct MyConfig {}
        struct S {
          @Attribute
          var config: MyConfig? = nil
        }
        """
    )
    #expect(
      result.diagnostics.contains { $0.contains("`.default` storage only supports primitive") })
  }

  @Test("Attribute raw allows non-primitive type")
  func attributeRawAllowsNonPrimitive() throws {
    let result = try MacroTestSupport.expand(
      source: """
        enum Status: String { case a, b }
        struct S {
          @Attribute(storageMethod: .raw)
          var status: Status? = .a
        }
        """
    )
    #expect(result.diagnostics.isEmpty)
  }

  @Test("Attribute raw rejects primitive type")
  func attributeRawRejectsPrimitiveType() throws {
    let result = try MacroTestSupport.expand(
      source: """
        struct S {
          @Attribute(storageMethod: .raw)
          var count: Int? = nil
        }
        """
    )
    #expect(result.diagnostics.contains { $0.contains("`.raw` requires a RawRepresentable type") })
  }

  @Test("Attribute composition rejects primitive type")
  func attributeCompositionRejectsPrimitiveType() throws {
    let result = try MacroTestSupport.expand(
      source: """
        struct S {
          @Attribute(storageMethod: .composition)
          var value: String? = nil
        }
        """
    )
    #expect(
      result.diagnostics.contains {
        $0.contains("`.composition` requires a @Composition struct type")
      })
  }

  @Test("Attribute transformed requires metatype argument")
  func attributeTransformedRequiresMetatypeArgument() throws {
    let result = try MacroTestSupport.expand(
      source: """
        final class T: ValueTransformer {}
        struct S {
          @Attribute(storageMethod: .transformed(T))
          var color: String? = nil
        }
        """
    )
    #expect(result.diagnostics.contains { $0.contains("requires a transformer metatype argument") })
  }

  @Test("Attribute decodeFailurePolicy supports transformed")
  func attributeDecodeFailurePolicySupportsTransformed() throws {
    let result = try MacroTestSupport.expand(
      source: """
        final class T: ValueTransformer {}
        struct S {
          @Attribute(storageMethod: .transformed(T.self), decodeFailurePolicy: .debugAssertNil)
          var color: String? = nil
        }
        """
    )
    #expect(result.diagnostics.isEmpty)
  }

  @Test("Attribute decodeFailurePolicy rejects unsupported storage")
  func attributeDecodeFailurePolicyRejectsUnsupportedStorage() throws {
    let result = try MacroTestSupport.expand(
      source: """
        struct S {
          @Attribute(storageMethod: .composition, decodeFailurePolicy: .debugAssertNil)
          var magnitude: [String: Any]? = nil
        }
        """
    )
    #expect(
      result.diagnostics.contains {
        $0.contains("only supported for `.raw`, `.codable`, and `.transformed`")
      })
  }

  @Test("Attribute optional property can omit default value")
  func attributeOptionalPropertyCanOmitDefaultValue() throws {
    let result = try MacroTestSupport.expand(
      source: """
        struct S {
          @Attribute
          var count: Int?
        }
        """
    )
    #expect(result.diagnostics.isEmpty)
  }

  @Test("Attribute non-optional property requires default value")
  func attributeNonOptionalPropertyRequiresDefaultValue() throws {
    let result = try MacroTestSupport.expand(
      source: """
        struct S {
          @Attribute
          var count: Int
        }
        """
    )
    #expect(
      result.diagnostics.contains {
        $0.contains("non-optional properties must declare a default value")
      })
  }

  @Test("Attribute originalName rejects interpolation")
  func attributeOriginalNameRejectsInterpolation() throws {
    let result = try MacroTestSupport.expand(
      source: """
        let suffix = "stamp"
        struct S {
          @Attribute(originalName: "time\\(suffix)")
          var date: Date? = nil
        }
        """
    )
    #expect(result.diagnostics.contains { $0.contains("must be a string literal or nil") })
  }

  @Test("Attribute originalName validates core data name format")
  func attributeOriginalNameValidatesCoreDataNameFormat() throws {
    let result = try MacroTestSupport.expand(
      source: """
        struct S {
          @Attribute(originalName: "9-bad-name")
          var date: Date? = nil
        }
        """
    )
    #expect(result.diagnostics.contains { $0.contains("valid Core Data attribute name") })
  }

  @Test("Attribute rejects old original label")
  func attributeRejectsOldOriginalLabel() throws {
    let result = try MacroTestSupport.expand(
      source: """
        struct S {
          @Attribute(original: "timestamp")
          var date: Date? = nil
        }
        """
    )
    #expect(result.diagnostics.contains { $0.contains("unknown argument label `original`") })
  }

  @Test("Composition rejects non-struct declaration")
  func compositionRejectsNonStruct() throws {
    let result = try MacroTestSupport.expand(
      source: """
        @Composition
        final class Location {
          var x: Double = 0
        }
        """
    )
    #expect(result.diagnostics.contains { $0.contains("only be attached to a struct") })
  }

  @Test("Composition rejects generic struct")
  func compositionRejectsGenericStruct() throws {
    let result = try MacroTestSupport.expand(
      source: """
        @Composition
        struct Box<T> {
          var value: T
        }
        """
    )
    #expect(result.diagnostics.contains { $0.contains("does not support generic structs") })
  }

  @Test("Composition rejects let and computed properties")
  func compositionRejectsLetAndComputed() throws {
    let result = try MacroTestSupport.expand(
      source: """
        @Composition
        struct Location {
          let x: Double
          var y: Double { 1 }
        }
        """
    )
    #expect(result.diagnostics.contains { $0.contains("only processes `var` stored properties") })
    #expect(result.diagnostics.contains { $0.contains("does not support computed properties") })
  }

  @Test("Composition rejects unsupported field type")
  func compositionRejectsUnsupportedType() throws {
    let result = try MacroTestSupport.expand(
      source: """
        @Composition
        struct Location {
          var point: CGPoint
        }
        """
    )
    #expect(result.diagnostics.contains { $0.contains("field type is unsupported in v1") })
  }

  @Test("Composition accepts allowed primitive and optional fields")
  func compositionAcceptsAllowedFields() throws {
    let result = try MacroTestSupport.expand(
      source: """
        import Foundation
        @Composition
        public struct Location {
          public var x: Double
          public var amount: Decimal?
          public var name: String?
          public var webpage: URL?
        }
        """
    )
    #expect(result.diagnostics.isEmpty)
    #expect(result.expandedSource.contains("__cdCompositionFieldTable"))
    #expect(result.expandedSource.contains("__cdDecodeComposition"))
    #expect(result.expandedSource.contains("__cdEncodeComposition"))
  }

  @Test("Composition generated members keep type access level")
  func compositionKeepsAccessLevel() throws {
    let result = try MacroTestSupport.expand(
      source: """
        @Composition
        private struct LocalLocation {
          var x: Double
        }
        """
    )
    #expect(result.diagnostics.isEmpty)
    #expect(result.expandedSource.contains("private static let __cdCompositionFieldTable"))
    #expect(result.expandedSource.contains("private static func __cdDecodeComposition"))
    #expect(result.expandedSource.contains("private var __cdEncodeComposition"))
  }

  @Test("Ignore accepts stored var property")
  func ignoreAcceptsStoredVarProperty() throws {
    let result = try MacroTestSupport.expand(
      source: """
        struct S {
          @Ignore
          var transientValue: Int = 0
        }
        """
    )
    #expect(result.diagnostics.isEmpty)
  }

  @Test("Ignore rejects let property")
  func ignoreRejectsLetProperty() throws {
    let result = try MacroTestSupport.expand(
      source: """
        struct S {
          @Ignore
          let transientValue: Int = 0
        }
        """
    )
    #expect(result.diagnostics.contains { $0.contains("stored `var` property") })
  }

  @Test("Ignore rejects computed property")
  func ignoreRejectsComputedProperty() throws {
    let result = try MacroTestSupport.expand(
      source: """
        struct S {
          @Ignore
          var transientValue: Int { 0 }
        }
        """
    )
    #expect(result.diagnostics.contains { $0.contains("stored `var` property") })
  }

  @Test("Ignore rejects non-property declaration")
  func ignoreRejectsNonPropertyDeclaration() throws {
    let result = try MacroTestSupport.expand(
      source: """
        @Ignore
        func f() {}
        """
    )
    #expect(result.diagnostics.contains { $0.contains("stored `var` property") })
  }
}
