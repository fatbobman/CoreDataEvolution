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

  private func containsObservationAccess(_ source: String, property: String) -> Bool {
    source.contains("CoreDataEvolution._cdeObservationAccess(")
      && source.contains("\\.\(property),")
      && source.contains("registrar: _$observationRegistrar")
  }
}
