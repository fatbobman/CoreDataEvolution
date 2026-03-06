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
  @Test("NSModelActor private type uses fileprivate witnesses")
  func nsModelActorPrivateUsesFileprivateWitnesses() throws {
    let result = try MacroTestSupport.expand(
      source: """
        import CoreData
        import CoreDataEvolution
        @NSModelActor(disableGenerateInit: true)
        private actor PrivateHandler {
          init(container: NSPersistentContainer) {
            modelContainer = container
            modelExecutor = .init(context: container.newBackgroundContext())
          }
        }
        """
    )
    #expect(result.diagnostics.isEmpty)
    #expect(result.expandedSource.contains("fileprivate nonisolated let modelExecutor"))
    #expect(result.expandedSource.contains("fileprivate nonisolated let modelContainer"))
    #expect(
      result.expandedSource.contains("extension PrivateHandler: CoreDataEvolution.NSModelActor {")
    )
    #expect(result.expandedSource.contains("fileprivate extension") == false)
  }

  @Test("NSModelActor public type keeps public witnesses")
  func nsModelActorPublicKeepsPublicWitnesses() throws {
    let result = try MacroTestSupport.expand(
      source: """
        import CoreData
        import CoreDataEvolution
        @NSModelActor(disableGenerateInit: true)
        public actor PublicHandler {
          public init(container: NSPersistentContainer) {
            modelContainer = container
            modelExecutor = .init(context: container.newBackgroundContext())
          }
        }
        """
    )
    #expect(result.diagnostics.isEmpty)
    #expect(result.expandedSource.contains("public nonisolated let modelExecutor"))
    #expect(result.expandedSource.contains("public nonisolated let modelContainer"))
  }

  @Test("NSMainModelActor private type uses fileprivate witness")
  func nsMainModelActorPrivateUsesFileprivateWitness() throws {
    let result = try MacroTestSupport.expand(
      source: """
        import CoreData
        import CoreDataEvolution
        @NSMainModelActor(disableGenerateInit: true)
        @MainActor
        private final class PrivateMainHandler {
          init(modelContainer: NSPersistentContainer) {
            self.modelContainer = modelContainer
          }
        }
        """
    )
    #expect(result.diagnostics.isEmpty)
    #expect(result.expandedSource.contains("fileprivate let modelContainer"))
    #expect(
      result.expandedSource.contains(
        "extension PrivateMainHandler: CoreDataEvolution.NSMainModelActor {")
    )
    #expect(result.expandedSource.contains("fileprivate extension") == false)
  }

  @Test("PersistentModel private type uses fileprivate generated members")
  func persistentModelPrivateUsesFileprivateGeneratedMembers() throws {
    let result = try MacroTestSupport.expand(
      source: """
        import CoreData
        import CoreDataEvolution
        @objc(PrivateItem)
        @PersistentModel
        private final class PrivateItem: NSManagedObject {
          var title: String = ""
        }
        """
    )
    #expect(result.diagnostics.isEmpty)
    #expect(result.expandedSource.contains("fileprivate enum Keys: String"))
    #expect(result.expandedSource.contains("fileprivate enum Paths"))
    #expect(result.expandedSource.contains("fileprivate static var path: PathRoot"))
    #expect(result.expandedSource.contains("fileprivate static let __cdFieldTable"))
  }

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
        @objc(S)
        @PersistentModel(relationshipGetterPolicy: .plain)
        final class S: NSManagedObject {}
        """
    )
    #expect(
      result.diagnostics.contains {
        $0.contains("unknown argument label `relationshipGetterPolicy`")
      })
  }

  @Test("PersistentModel requires explicit objc class name")
  func persistentModelRequiresExplicitObjCClassName() throws {
    let result = try MacroTestSupport.expand(
      source: """
        import CoreData
        import CoreDataEvolution
        @PersistentModel
        final class S: NSManagedObject {}
        """
    )
    #expect(
      result.diagnostics.contains {
        $0.contains("must declare @objc(ClassName) explicitly")
      })
  }

  @Test("PersistentModel count policy emits guidance and no count accessors")
  func persistentModelCountPolicyEmitsGuidanceAndNoCountAccessors() throws {
    let result = try MacroTestSupport.expand(
      source: """
        import CoreData
        import CoreDataEvolution
        @objc(Item)
        @PersistentModel(relationshipCountPolicy: .plain)
        final class Item: NSManagedObject {
          var tags: Set<Tag>
          var orderedTags: [Tag]
        }
        """
    )
    #expect(
      result.diagnostics.contains {
        $0.contains("relationshipCountPolicy` is guidance-only in v1")
      })
    #expect(result.expandedSource.contains("var tagsCount: Int") == false)
    #expect(result.expandedSource.contains("var orderedTagsCount: Int") == false)
  }

  @Test("PersistentModel warning setter policy marks to-many setter deprecated")
  func persistentModelWarningSetterPolicyMarksToManySetterDeprecated() throws {
    let result = try MacroTestSupport.expand(
      source: """
        import CoreData
        import CoreDataEvolution
        @objc(Item)
        @PersistentModel(relationshipSetterPolicy: .warning)
        final class Item: NSManagedObject {
          var tags: Set<Tag>
        }
        """
    )
    #expect(result.diagnostics.isEmpty)
    #expect(
      result.expandedSource.contains(
        "Bulk to-many setter may hide relationship mutation costs. Prefer add/remove helpers."))
    #expect(result.expandedSource.contains("setValue(NSSet(set: newValue), forKey: \"tags\")"))
  }

  @Test("PersistentModel validates relationship target as PersistentEntity")
  func persistentModelValidatesRelationshipTargetAsPersistentEntity() throws {
    let result = try MacroTestSupport.expand(
      source: """
        import CoreData
        import CoreDataEvolution
        @objc(Item)
        @PersistentModel
        final class Item: NSManagedObject {
          var category: Category?
          var tags: Set<Tag>
        }
        """
    )
    #expect(result.diagnostics.isEmpty)
    #expect(
      result.expandedSource.contains(
        "_CDRelationshipMacroValidation.requirePersistentEntity(Category.self)"))
    #expect(
      result.expandedSource.contains(
        "_CDRelationshipMacroValidation.requirePersistentEntity(Tag.self)"))
  }

  @Test("PersistentModel auto-applies Attribute to unannotated persisted var")
  func persistentModelAutoAppliesAttributeToUnannotatedPersistedVar() throws {
    let result = try MacroTestSupport.expand(
      source: """
        import CoreData
        import CoreDataEvolution
        @objc(Item)
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

  @Test("Attribute unique trait is accepted and feeds runtime schema")
  func attributeUniqueTraitFeedsRuntimeSchema() throws {
    let result = try MacroTestSupport.expand(
      source: """
        import CoreData
        import CoreDataEvolution
        @objc(Item)
        @PersistentModel
        final class Item: NSManagedObject {
          @Attribute(.unique)
          var title: String = ""
        }
        """
    )
    #expect(result.diagnostics.isEmpty)
    #expect(result.expandedSource.contains("isUnique: true"))
    #expect(
      result.expandedSource.contains(
        "persistentPropertyNames: [\"title\"]"))
  }

  @Test("Attribute transient trait is accepted and feeds runtime schema")
  func attributeTransientTraitFeedsRuntimeSchema() throws {
    let result = try MacroTestSupport.expand(
      source: """
        import CoreData
        import CoreDataEvolution
        @objc(Item)
        @PersistentModel
        final class Item: NSManagedObject {
          @Attribute(.transient)
          var cachedSummary: String = ""
        }
        """
    )
    #expect(result.diagnostics.isEmpty)
    #expect(result.expandedSource.contains("isTransient: true"))
  }

  @Test("Attribute transient trait rejects custom storage")
  func attributeTransientTraitRejectsCustomStorage() throws {
    let result = try MacroTestSupport.expand(
      source: """
        import CoreDataEvolution
        struct Item {
          @Attribute(.transient, storageMethod: .raw)
          var cachedSummary: String = ""
        }
        """
    )
    #expect(
      result.diagnostics.contains {
        $0.contains("trait `.transient` only supports `.default` storage")
      })
  }

  @Test("Attribute rejects unsupported unlabeled traits")
  func attributeRejectsUnsupportedUnlabeledTraits() throws {
    let result = try MacroTestSupport.expand(
      source: """
        import CoreDataEvolution
        struct Item {
          @Attribute(.indexed)
          var title: String = ""
        }
        """
    )
    #expect(
      result.diagnostics.contains {
        $0.contains("only supports the `.unique` and `.transient` traits")
      })
  }

  @Test("PersistentModel default does not generate init")
  func persistentModelDefaultDoesNotGenerateInit() throws {
    let result = try MacroTestSupport.expand(
      source: """
        import CoreData
        import CoreDataEvolution
        @objc(Item)
        @PersistentModel
        final class Item: NSManagedObject {
          var title: String = ""
        }
        """
    )
    #expect(result.diagnostics.isEmpty)
    #expect(result.expandedSource.contains("convenience init(") == false)
  }

  @Test("PersistentModel init excludes relationships and includes Ignore without defaults")
  func persistentModelInitExcludesRelationshipsAndIncludesIgnoreWithoutDefaults() throws {
    let result = try MacroTestSupport.expand(
      source: """
        import CoreData
        import CoreDataEvolution
        @objc(Item)
        @PersistentModel(generateInit: true)
        final class Item: NSManagedObject {
          var title: String = ""
          @Ignore
          var transientCache: [String: Int] = [:]
          var tags: Set<Tag>
          var category: Category?
        }
        """
    )
    #expect(result.diagnostics.isEmpty)
    #expect(result.expandedSource.contains("convenience init("))
    #expect(result.expandedSource.contains("title: String,"))
    #expect(result.expandedSource.contains("transientCache: [String: Int]"))
    #expect(result.expandedSource.contains("self.transientCache = transientCache"))
    #expect(result.expandedSource.contains("self.title = title"))
    #expect(result.expandedSource.contains("self.init(entity: Self.entity(), insertInto: nil)"))
    #expect(
      result.expandedSource.contains(
        "convenience init(\n    title: String,\n    transientCache: [String: Int]\n  )"))
  }

  @Test("PersistentModel rejects optional to-many relationship declaration")
  func persistentModelRejectsOptionalToManyRelationshipDeclaration() throws {
    let result = try MacroTestSupport.expand(
      source: """
        import CoreData
        import CoreDataEvolution
        @objc(Item)
        @PersistentModel
        final class Item: NSManagedObject {
          var tags: Set<Tag>?
        }
        """
    )
    #expect(
      result.diagnostics.contains {
        $0.contains("Optional to-many relationship")
      })
  }

  @Test("PersistentModel rejects non-optional to-one relationship declaration")
  func persistentModelRejectsNonOptionalToOneRelationshipDeclaration() throws {
    let result = try MacroTestSupport.expand(
      source: """
        import CoreData
        import CoreDataEvolution
        @objc(Item)
        @PersistentModel
        final class Item: NSManagedObject {
          var category: Category
        }
        """
    )
    #expect(
      result.diagnostics.contains {
        $0.contains("To-one relationship properties must be optional")
      })
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
