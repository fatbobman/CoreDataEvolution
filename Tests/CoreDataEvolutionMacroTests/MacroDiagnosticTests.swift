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
        @Composition
        public struct Location {
          public var x: Double
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
}
