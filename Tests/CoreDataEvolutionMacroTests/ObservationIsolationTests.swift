//
//  ------------------------------------------------
//  Original project: CoreDataEvolution
//  Created on 2026/5/30 by Fatbobman(东坡肘子)
//  X: @fatbobman
//  Mastodon: @fatbobman@mastodon.social
//  GitHub: @fatbobman
//  Blog: https://fatbobman.com
//  ------------------------------------------------
//  Copyright © 2024-present Fatbobman. All rights reserved.

import Testing

@Suite("Observation Isolation")
struct ObservationIsolationTests {
  @Test("T02 non opt-in PersistentModel expansion stays Observation-free")
  func nonOptInPersistentModelExpansionStaysObservationFree() throws {
    let result = try MacroTestSupport.expand(
      source: """
        import CoreData
        import CoreDataEvolution

        @objc(CDIsolationItem)
        @PersistentModel
        final class CDIsolationItem: NSManagedObject {
          var name: String = ""
          var timestamp: Date?
        }
        """
    )

    #expect(result.diagnostics.isEmpty)
    #expect(result.expandedSource.contains("Observation") == false)
    #expect(result.expandedSource.contains("ObservationRegistrar") == false)
    #expect(result.expandedSource.contains("@Observable") == false)
    #expect(result.formattedExpandedSource.contains("Observation") == false)
    #expect(result.formattedExpandedSource.contains("ObservationRegistrar") == false)
    #expect(result.formattedExpandedSource.contains("@Observable") == false)
  }

  @Test("explicit none matches implicit PersistentModel expansion")
  func explicitNoneMatchesImplicitPersistentModelExpansion() throws {
    let implicit = try MacroTestSupport.expand(
      source: """
        import CoreData
        import CoreDataEvolution

        @objc(CDIsolationItem)
        @PersistentModel
        final class CDIsolationItem: NSManagedObject {
          var name: String = ""
          var timestamp: Date?
        }
        """
    )
    let explicit = try MacroTestSupport.expand(
      source: """
        import CoreData
        import CoreDataEvolution

        @objc(CDIsolationItem)
        @PersistentModel(observation: .none)
        final class CDIsolationItem: NSManagedObject {
          var name: String = ""
          var timestamp: Date?
        }
        """
    )

    #expect(implicit.diagnostics.isEmpty)
    #expect(explicit.diagnostics.isEmpty)
    #expect(explicit.expandedSource == implicit.expandedSource)
    #expect(explicit.expandedSource.contains("Observation") == false)
    #expect(explicit.expandedSource.contains("ObservationRegistrar") == false)
    #expect(explicit.expandedSource.contains("@Observable") == false)
  }

  @Test("mainActor observation argument parses without diagnostics")
  func mainActorObservationArgumentParsesWithoutDiagnostics() throws {
    let result = try MacroTestSupport.expand(
      source: """
        import CoreData
        import CoreDataEvolution

        @objc(CDObservedItem)
        @PersistentModel(observation: .mainActor)
        final class CDObservedItem: NSManagedObject {
          var name: String = ""
          var timestamp: Date?
        }
        """
    )

    #expect(result.diagnostics.isEmpty)
    #expect(result.expandedSource.contains("enum Keys"))
  }

  @Test("observed PersistentModel still requires NSManagedObject inheritance")
  func observedPersistentModelStillRequiresNSManagedObjectInheritance() throws {
    let result = try MacroTestSupport.expand(
      source: """
        import CoreData
        import CoreDataEvolution

        @objc(CDObservedItem)
        @PersistentModel(observation: .mainActor)
        final class CDObservedItem {
          var name: String = ""
        }
        """
    )

    #expect(result.diagnostics.count == 1)
    #expect(
      result.diagnostics.first?.contains(
        "@PersistentModel type must inherit from NSManagedObject."
      ) == true)
  }

  @Test("invalid observation argument emits one diagnostic")
  func invalidObservationArgumentEmitsOneDiagnostic() throws {
    let result = try MacroTestSupport.expand(
      source: """
        import CoreData
        import CoreDataEvolution

        @objc(CDObservedItem)
        @PersistentModel(observation: 123)
        final class CDObservedItem: NSManagedObject {
          var name: String = ""
        }
        """
    )

    #expect(result.diagnostics.count == 1)
    #expect(
      result.diagnostics.first?.contains(
        "@PersistentModel argument `observation` must be `.none` or `.mainActor`."
      ) == true)
  }

  @Test("observed NSManaged property skips generated accessor with warning")
  func observedNSManagedPropertySkipsGeneratedAccessorWithWarning() throws {
    let result = try MacroTestSupport.expand(
      source: """
        import CoreData
        import CoreDataEvolution

        @objc(CDObservedItem)
        @PersistentModel(observation: .mainActor)
        final class CDObservedItem: NSManagedObject {
          @NSManaged var legacyName: String
        }
        """
    )

    #expect(result.diagnostics.count == 1)
    #expect(
      result.diagnostics.first?.contains(
        "@NSManaged property `legacyName` will not participate in Observation"
      ) == true)
    #expect(result.expandedSource.contains("@NSManaged var legacyName: String"))
    #expect(result.expandedSource.contains("value(forKey: \"legacyName\")") == false)
    #expect(result.expandedSource.contains("__cd_attribute_validate_legacyName") == false)
  }
}
