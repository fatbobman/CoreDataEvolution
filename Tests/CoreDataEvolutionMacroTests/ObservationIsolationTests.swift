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
}
