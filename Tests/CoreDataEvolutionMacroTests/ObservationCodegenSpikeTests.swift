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

import Testing

@Suite("Observation Codegen Spike")
struct ObservationCodegenSpikeTests {
  @Test("mainActor observation instruments auto and manual accessors")
  func mainActorObservationInstrumentsAutoAndManualAccessors() throws {
    let result = try MacroTestSupport.expand(
      source: """
        import CoreData
        import CoreDataEvolution

        @objc(CDObservedItem)
        @PersistentModel(observation: .mainActor)
        final class CDObservedItem: NSManagedObject {
          var name: String = ""

          @Attribute(.unique)
          var code: String = ""

          @Relationship(inverse: "items", deleteRule: .nullify)
          var category: CDObservedCategory?
        }
        """
    )

    #expect(result.diagnostics.isEmpty)
    #expect(
      result.expandedSource.contains("extension CDObservedItem: CoreDataEvolution.CDEObservable"))
    #expect(
      result.expandedSource.contains(
        "private let _$observationRegistrar = CoreDataEvolution.CDEObservationRegistrar()"
      ))
    #expect(containsObservationAccess(result.expandedSource, property: "name"))
    #expect(containsObservationAccess(result.expandedSource, property: "code"))
    #expect(containsObservationAccess(result.expandedSource, property: "category"))
  }

  @Test("mainActor observation codegen is availability gated")
  func mainActorObservationCodegenIsAvailabilityGated() throws {
    let result = try MacroTestSupport.expand(
      source: """
        import CoreData
        import CoreDataEvolution

        @objc(CDObservedItem)
        @PersistentModel(observation: .mainActor)
        final class CDObservedItem: NSManagedObject {
          var name: String = ""
        }
        """
    )

    #expect(result.diagnostics.isEmpty)
    let availability =
      "@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)"
    #expect(result.expandedSource.contains("\(availability)\n  private let _$observationRegistrar"))
    #expect(result.expandedSource.contains("\(availability) get {"))
    #expect(result.expandedSource.contains("\(availability)\nextension CDObservedItem"))
  }

  @Test("mainActor observation generates Core Data key fan-out table")
  func mainActorObservationGeneratesCoreDataKeyFanOutTable() throws {
    let result = try MacroTestSupport.expand(
      source: """
        import CoreData
        import CoreDataEvolution

        @Composition
        struct CDObservedProfile {
          var nickname: String = ""
        }

        @objc(CDObservedParent)
        @PersistentModel(observation: .mainActor)
        final class CDObservedParent: NSManagedObject {
          @Attribute(persistentName: "display_name")
          var name: String = ""

          @Relationship(inverse: "favoriteOf", deleteRule: .nullify)
          var favorite: CDObservedChild?

          @Relationship(persistentName: "kid_records", inverse: "parent", deleteRule: .nullify)
          var children: Set<CDObservedChild>

          @Relationship(
            persistentName: "ordered_kid_records",
            inverse: "orderedParent",
            deleteRule: .nullify
          )
          var orderedChildren: [CDObservedChild]

          @Attribute(persistentName: "profileStorage", storageMethod: .composition)
          var profile: CDObservedProfile? = nil

          @Attribute(.transient)
          var transientNote: String = ""
        }
        """
    )

    #expect(result.diagnostics.isEmpty)
    #expect(result.expandedSource.contains("private enum __CDObservationFieldID: UInt16"))
    #expect(result.expandedSource.contains("case childrenCount"))
    #expect(result.expandedSource.contains("case orderedChildrenCount"))
    #expect(
      result.expandedSource.contains(
        #""display_name": .init(rawValues: [__CDObservationFieldID.name.rawValue])"#
      ))
    #expect(
      result.expandedSource.contains(
        #""kid_records": .init(rawValues: [__CDObservationFieldID.children.rawValue, __CDObservationFieldID.childrenCount.rawValue])"#
      ))
    #expect(
      result.expandedSource.contains(
        #""ordered_kid_records": .init(rawValues: [__CDObservationFieldID.orderedChildren.rawValue, __CDObservationFieldID.orderedChildrenCount.rawValue])"#
      ))
    #expect(
      result.expandedSource.contains(
        #""profileStorage": .init(rawValues: [__CDObservationFieldID.profile.rawValue])"#
      ))
    #expect(result.expandedSource.contains(#""transientNote": .init(rawValues:"#) == false)
    #expect(containsObservationAccess(result.expandedSource, property: "childrenCount"))
    #expect(containsObservationAccess(result.expandedSource, property: "orderedChildrenCount"))
    #expect(result.expandedSource.contains("func __cdObservationInvalidate("))
    #expect(
      result.expandedSource.contains("fieldSet: CoreDataEvolution.CDEObservationFieldSet"))
    #expect(
      result.expandedSource.contains(
        "_$observationRegistrar.withMutation(of: self, keyPath: \\.children)"
      ))
    #expect(
      result.expandedSource.contains(
        "_$observationRegistrar.withMutation(of: self, keyPath: \\.childrenCount)"
      ))
  }

  private func containsObservationAccess(_ source: String, property: String) -> Bool {
    source.contains("CoreDataEvolution._cdeObservationAccess(")
      && source.contains("\\.\(property),")
      && source.contains("registrar: _$observationRegistrar")
  }
}
