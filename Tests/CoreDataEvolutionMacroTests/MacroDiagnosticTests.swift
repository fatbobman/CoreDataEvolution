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

  @Test("PersistentModel public type keeps public typed path members")
  func persistentModelPublicKeepsPublicTypedPathMembers() throws {
    let result = try MacroTestSupport.expand(
      source: """
        import CoreData
        import CoreDataEvolution
        @objc(PublicItem)
        @PersistentModel
        public final class PublicItem: NSManagedObject {
          public var title: String = ""
        }
        """
    )
    #expect(result.diagnostics.isEmpty)
    #expect(result.expandedSource.contains("public enum Keys: String"))
    #expect(result.expandedSource.contains("public enum Paths"))
    #expect(result.expandedSource.contains("public static let title = CoreDataEvolution.CDPath"))
    #expect(result.expandedSource.contains("public struct PathRoot: Sendable"))
    #expect(result.expandedSource.contains("public var title: CoreDataEvolution.CDPath"))
    #expect(result.expandedSource.contains("public static var path: PathRoot"))
    #expect(
      result.expandedSource.contains(
        "@nonobjc\n  public class func fetchRequest() -> NSFetchRequest<PublicItem>")
    )
  }

  @Test("PersistentModel does not duplicate user fetchRequest")
  func persistentModelDoesNotDuplicateUserFetchRequest() throws {
    let result = try MacroTestSupport.expand(
      source: """
        import CoreData
        import CoreDataEvolution
        @objc(Item)
        @PersistentModel
        final class Item: NSManagedObject {
          var title: String = ""

          @nonobjc
          class func fetchRequest() -> NSFetchRequest<Item> {
            NSFetchRequest<Item>(entityName: "Item")
          }
        }
        """
    )
    #expect(result.diagnostics.isEmpty)
    #expect(result.expandedSource.components(separatedBy: "class func fetchRequest()").count == 2)
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

  @Test("PersistentModel does not generate count accessors for to-many relationships")
  func persistentModelDoesNotGenerateCountAccessors() throws {
    let result = try MacroTestSupport.expand(
      source: """
        import CoreData
        import CoreDataEvolution
        @objc(Item)
        final class Item: NSManagedObject {
          @Relationship(inverse: "items", deleteRule: .nullify)
          var tags: Set<Tag>
          @Relationship(inverse: "orderedItems", deleteRule: .nullify)
          var orderedTags: [Tag]
        }
        """
    )
    #expect(result.diagnostics.isEmpty)
    #expect(result.expandedSource.contains("var tagsCount: Int") == false)
    #expect(result.expandedSource.contains("var orderedTagsCount: Int") == false)
  }

  @Test("PersistentModel does not generate bulk replacement helpers for to-many relationships")
  func persistentModelDoesNotGenerateBulkReplacementHelpers() throws {
    let result = try MacroTestSupport.expand(
      source: """
        import CoreData
        import CoreDataEvolution
        @objc(Item)
        final class Item: NSManagedObject {
          @Relationship(inverse: "items", deleteRule: .nullify)
          var tags: Set<Tag>
        }
        """
    )
    #expect(result.diagnostics.isEmpty)
    #expect(result.expandedSource.contains("func replaceTags(with values: Set<Tag>)") == false)
    #expect(
      result.expandedSource.contains("setValue(NSSet(set: newValue), forKey: \"tags\")") == false)
  }

  @Test("PersistentModel rejects default values on to-many relationships")
  func persistentModelRejectsDefaultValuesOnToManyRelationships() throws {
    let result = try MacroTestSupport.expand(
      source: """
        import CoreData
        import CoreDataEvolution
        @objc(Item)
        @PersistentModel
        final class Item: NSManagedObject {
          @Relationship(inverse: "items", deleteRule: .nullify)
          var tags: Set<Tag> = []
        }
        """
    )
    #expect(
      result.diagnostics.contains {
        $0.contains("must not declare a default value")
      })
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
          @Relationship(inverse: "category", deleteRule: .nullify)
          var category: Category?
          @Relationship(inverse: "items", deleteRule: .nullify)
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
          @Relationship(inverse: "items", deleteRule: .nullify)
          var tags: Set<Tag>
          @Relationship(inverse: "category", deleteRule: .nullify)
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

  @Test("PersistentModel init includes custom storage properties and Ignore")
  func persistentModelInitIncludesCustomStorageProperties() throws {
    let result = try MacroTestSupport.expand(
      source: """
        import CoreData
        import CoreDataEvolution

        struct Payload: Codable {}
        enum Status: String { case draft }
        final class T: ValueTransformer, CDRegisteredValueTransformer {
          static let transformerName = NSValueTransformerName("T")
        }

        @Composition
        struct Point {
          var x: Double = 0
        }

        @objc(Item)
        @PersistentModel(generateInit: true)
        final class Item: NSManagedObject {
          @Attribute(storageMethod: .raw)
          var status: Status? = nil

          @Attribute(storageMethod: .codable)
          var payload: Payload? = nil

          @Attribute(storageMethod: .composition)
          var point: Point? = nil

          @Attribute(storageMethod: .transformed(T.self))
          var keywords: [String]? = nil

          @Ignore
          var transientCache: [String: Int] = [:]

          @Relationship(inverse: "item", deleteRule: .nullify)
          var tag: Tag?
        }
        """
    )
    #expect(result.diagnostics.isEmpty)
    #expect(
      result.expandedSource.contains(
        """
        convenience init(
            status: Status?,
            payload: Payload?,
            point: Point?,
            keywords: [String]?,
            transientCache: [String: Int]
          )
        """
      )
    )
    #expect(result.expandedSource.contains("self.status = status"))
    #expect(result.expandedSource.contains("self.payload = payload"))
    #expect(result.expandedSource.contains("self.point = point"))
    #expect(result.expandedSource.contains("self.keywords = keywords"))
    #expect(result.expandedSource.contains("self.transientCache = transientCache"))
    #expect(result.expandedSource.contains("convenience init(\n    tag: Tag?") == false)
    #expect(result.expandedSource.contains(",\n    tag: Tag?") == false)
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

  @Test("PersistentModel accepts optional transformed array attributes")
  func persistentModelAcceptsOptionalTransformedArrayAttributes() throws {
    let result = try MacroTestSupport.expand(
      source: """
        import CoreData
        import CoreDataEvolution
        final class T: ValueTransformer, CDRegisteredValueTransformer {
          static let transformerName = NSValueTransformerName("T")
        }
        @objc(Item)
        @PersistentModel
        final class Item: NSManagedObject {
          @Attribute(storageMethod: .transformed(T.self))
          var tags: [String]? = nil
        }
        """
    )
    #expect(result.diagnostics.isEmpty)
    #expect(result.expandedSource.contains("var tags: [String]?"))
  }

  @Test("PersistentModel rejects multi-binding stored properties")
  func persistentModelRejectsMultiBindingStoredProperties() throws {
    let result = try MacroTestSupport.expand(
      source: """
        import CoreData
        import CoreDataEvolution
        @objc(Item)
        @PersistentModel
        final class Item: NSManagedObject {
          var title: String = "", subtitle: String = ""
        }
        """
    )
    #expect(
      result.diagnostics.contains {
        $0.contains(
          "does not support declaring multiple stored properties in one `var` declaration")
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

  @Test("PersistentModel requires relationship metadata for relationship properties")
  func persistentModelRequiresRelationshipMetadataForRelationshipProperties() throws {
    let result = try MacroTestSupport.expand(
      source: """
        import CoreData
        import CoreDataEvolution
        @objc(Document)
        @PersistentModel
        final class Document: NSManagedObject {
          var author: User?
          var editor: User?
        }
        """
    )
    #expect(
      result.diagnostics.contains {
        $0.contains(
          "must declare @Relationship(persistentName: ..., inverse: ..., deleteRule: ...)"
        )
      })
  }

  @Test("PersistentModel accepts explicit relationship metadata")
  func persistentModelAcceptsExplicitRelationshipMetadata() throws {
    let result = try MacroTestSupport.expand(
      source: """
        import CoreData
        import CoreDataEvolution
        @objc(Document)
        @PersistentModel
        final class Document: NSManagedObject {
          @Relationship(inverse: "authoredDocuments", deleteRule: .nullify)
          var author: User?

          @Relationship(inverse: "editedDocuments", deleteRule: .nullify)
          var editor: User?
        }
        """
    )
    #expect(result.diagnostics.isEmpty)
    #expect(result.expandedSource.contains(#"inverseName: "authoredDocuments""#))
    #expect(result.expandedSource.contains(#"inverseName: "editedDocuments""#))
    #expect(result.expandedSource.contains(#"deleteRule: .nullify"#))
  }

  @Test("Relationship accepts explicit min/max model counts")
  func relationshipAcceptsExplicitModelCounts() throws {
    let result = try MacroTestSupport.expand(
      source: """
        import CoreData
        import CoreDataEvolution
        @objc(Document)
        @PersistentModel
        final class Document: NSManagedObject {
          @Relationship(
            inverse: "authors",
            deleteRule: .deny,
            minimumModelCount: 1,
            maximumModelCount: 3
          )
          var contributors: [User]
        }
        """
    )
    #expect(result.diagnostics.isEmpty)
    #expect(result.expandedSource.contains(#"minimumModelCount: 1"#))
    #expect(result.expandedSource.contains(#"maximumModelCount: 3"#))
  }

  @Test("Relationship rejects invalid argument shapes")
  func relationshipRejectsInvalidArgumentShapes() throws {
    let result = try MacroTestSupport.expand(
      source: """
        import CoreData
        import CoreDataEvolution
        final class Document: NSManagedObject {
          @Relationship(inverse: "author")
          var author: User?
        }
        """
    )
    #expect(
      result.diagnostics.contains {
        $0.contains("@Relationship requires `deleteRule:`")
      })
  }

  @Test("Relationship rejects unsupported noAction delete rule")
  func relationshipRejectsUnsupportedNoActionDeleteRule() throws {
    let result = try MacroTestSupport.expand(
      source: """
        import CoreData
        import CoreDataEvolution
        final class Document: NSManagedObject {
          @Relationship(inverse: "author", deleteRule: .noAction)
          var author: User?
        }
        """
    )
    #expect(
      result.diagnostics.contains {
        $0.contains("does not support `deleteRule: .noAction`")
      })
  }

  @Test("Relationship rejects invalid minimumModelCount")
  func relationshipRejectsInvalidMinimumModelCount() throws {
    let result = try MacroTestSupport.expand(
      source: """
        import CoreData
        import CoreDataEvolution
        final class Document: NSManagedObject {
          @Relationship(inverse: "author", deleteRule: .nullify, minimumModelCount: -1)
          var author: User?
        }
        """
    )
    #expect(
      result.diagnostics.contains {
        $0.contains("minimumModelCount:` to be a non-negative integer literal")
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
        final class T: ValueTransformer, CDRegisteredValueTransformer {
          static let transformerName = NSValueTransformerName("T")
        }
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
        final class T: ValueTransformer, CDRegisteredValueTransformer {
          static let transformerName = NSValueTransformerName("T")
        }
        struct S {
          @Attribute(storageMethod: .transformed(T.self), decodeFailurePolicy: .debugAssertNil)
          var color: String? = nil
        }
        """
    )
    #expect(result.diagnostics.isEmpty)
  }

  @Test("Attribute transformed accepts built-in secure unarchive transformer")
  func attributeTransformedAcceptsBuiltInSecureUnarchiveTransformer() throws {
    let result = try MacroTestSupport.expand(
      source: """
        import Foundation
        import CoreDataEvolution
        struct S {
          @Attribute(storageMethod: .transformed(NSSecureUnarchiveFromDataTransformer.self))
          var payload: [String]? = nil
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

  @Test("Attribute codable rejects non-nil explicit default value")
  func attributeCodableRejectsNonNilExplicitDefaultValue() throws {
    let result = try MacroTestSupport.expand(
      source: """
        struct Payload: Codable {
          var title: String = ""
        }
        struct S {
          @Attribute(storageMethod: .codable)
          var payload: Payload? = .init()
        }
        """
    )
    #expect(
      result.diagnostics.contains {
        $0.contains("storageMethod `.codable` only supports nil as an explicit default value")
      })
  }

  @Test("Attribute transformed rejects non-nil explicit default value")
  func attributeTransformedRejectsNonNilExplicitDefaultValue() throws {
    let result = try MacroTestSupport.expand(
      source: """
        import Foundation
        final class T: ValueTransformer, CDRegisteredValueTransformer {
          static let transformerName = NSValueTransformerName("T")
        }
        struct S {
          @Attribute(storageMethod: .transformed(T.self))
          var colors: [String]? = []
        }
        """
    )
    #expect(
      result.diagnostics.contains {
        $0.contains("storageMethod `.transformed` only supports nil as an explicit default value")
      })
  }

  @Test("Attribute composition rejects non-nil explicit default value")
  func attributeCompositionRejectsNonNilExplicitDefaultValue() throws {
    let result = try MacroTestSupport.expand(
      source: """
        import CoreDataEvolution
        @Composition
        struct Point {
          var x: Double = 0
        }
        struct S {
          @Attribute(storageMethod: .composition)
          var point: Point? = .init()
        }
        """
    )
    #expect(
      result.diagnostics.contains {
        $0.contains("storageMethod `.composition` only supports nil as an explicit default value")
      })
  }

  @Test("Attribute custom storage currently requires optional declarations")
  func attributeCustomStorageRequiresOptionalDeclarations() throws {
    let codableResult = try MacroTestSupport.expand(
      source: """
        struct Payload: Codable {
          var title: String = ""
        }
        struct S {
          @Attribute(storageMethod: .codable)
          var payload: Payload = .init()
        }
        """
    )
    #expect(
      codableResult.diagnostics.contains {
        $0.contains("storageMethod `.codable` currently requires an optional property")
      })

    let transformedResult = try MacroTestSupport.expand(
      source: """
        import Foundation
        final class T: ValueTransformer, CDRegisteredValueTransformer {
          static let transformerName = NSValueTransformerName("T")
        }
        struct S {
          @Attribute(storageMethod: .transformed(T.self))
          var colors: [String] = []
        }
        """
    )
    #expect(
      transformedResult.diagnostics.contains {
        $0.contains("storageMethod `.transformed` currently requires an optional property")
      })

    let compositionResult = try MacroTestSupport.expand(
      source: """
        import CoreDataEvolution
        @Composition
        struct Point {
          var x: Double = 0
        }
        struct S {
          @Attribute(storageMethod: .composition)
          var point: Point = .init()
        }
        """
    )
    #expect(
      compositionResult.diagnostics.contains {
        $0.contains("storageMethod `.composition` currently requires an optional property")
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

  @Test("Attribute persistentName rejects interpolation")
  func attributePersistentNameRejectsInterpolation() throws {
    let result = try MacroTestSupport.expand(
      source: """
        let suffix = "stamp"
        struct S {
          @Attribute(persistentName: "time\\(suffix)")
          var date: Date? = nil
        }
        """
    )
    #expect(result.diagnostics.contains { $0.contains("must be a string literal or nil") })
  }

  @Test("Attribute persistentName validates core data name format")
  func attributePersistentNameValidatesCoreDataNameFormat() throws {
    let result = try MacroTestSupport.expand(
      source: """
        struct S {
          @Attribute(persistentName: "9-bad-name")
          var date: Date? = nil
        }
        """
    )
    #expect(result.diagnostics.contains { $0.contains("valid Core Data attribute name") })
  }

  @Test("Attribute rejects old persistent label")
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

  @Test("Composition accepts CompositionField persistent names")
  func compositionAcceptsCompositionFieldPersistentNames() throws {
    let result = try MacroTestSupport.expand(
      source: """
        import CoreDataEvolution
        @Composition
        struct Coordinate {
          @CompositionField(persistentName: "lat")
          var latitude: Double
          @CompositionField(persistentName: "lng")
          var longitude: Double?
        }
        """
    )
    #expect(result.diagnostics.isEmpty)
    #expect(result.expandedSource.contains(#"persistentPath: ["lat"]"#))
    #expect(result.expandedSource.contains(#"persistentName: "lng""#))
    #expect(result.expandedSource.contains(#"dictionary["lat"]"#))
  }

  @Test("CompositionField persistentName rejects interpolation")
  func compositionFieldPersistentNameRejectsInterpolation() throws {
    let result = try MacroTestSupport.expand(
      source: """
        import CoreDataEvolution
        let suffix = "itude"
        @Composition
        struct Coordinate {
          @CompositionField(persistentName: "lat\\(suffix)")
          var latitude: Double
        }
        """
    )
    #expect(
      result.diagnostics.contains {
        $0.contains("@CompositionField argument `persistentName` must be a string literal or nil")
      })
  }

  @Test("CompositionField rejects non-property declaration")
  func compositionFieldRejectsNonPropertyDeclaration() throws {
    let result = try MacroTestSupport.expand(
      source: """
        import CoreDataEvolution
        @CompositionField(persistentName: "lat")
        func latitude() {}
        """
    )
    #expect(
      result.diagnostics.contains {
        $0.contains("@CompositionField can only be attached to a `var` property declaration")
      })
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
