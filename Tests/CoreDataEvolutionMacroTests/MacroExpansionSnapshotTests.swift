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

@Suite("Macro Expansion Snapshot")
struct MacroExpansionSnapshotTests {
  @Test("Attribute default and original snapshot")
  func attributeDefaultAndOriginalSnapshot() throws {
    try MacroTestSupport.assertExpansionSnapshot(fixtureName: "AttributeDefaultAndOriginal")
  }

  @Test("Attribute raw snapshot")
  func attributeRawSnapshot() throws {
    try MacroTestSupport.assertExpansionSnapshot(fixtureName: "AttributeRaw")
  }

  @Test("Attribute codable snapshot")
  func attributeCodableSnapshot() throws {
    try MacroTestSupport.assertExpansionSnapshot(fixtureName: "AttributeCodable")
  }

  @Test("Attribute transformed snapshot")
  func attributeTransformedSnapshot() throws {
    try MacroTestSupport.assertExpansionSnapshot(fixtureName: "AttributeTransformed")
  }

  @Test("Attribute composition snapshot")
  func attributeCompositionSnapshot() throws {
    try MacroTestSupport.assertExpansionSnapshot(fixtureName: "AttributeComposition")
  }

  @Test("Composition basic snapshot")
  func compositionBasicSnapshot() throws {
    try MacroTestSupport.assertExpansionSnapshot(fixtureName: "CompositionBasic")
  }

  @Test("Ignore marker snapshot")
  func ignoreMarkerSnapshot() throws {
    try MacroTestSupport.assertExpansionSnapshot(fixtureName: "IgnoreMarker")
  }

  @Test("PersistentModel basic snapshot")
  func persistentModelBasicSnapshot() throws {
    try MacroTestSupport.assertExpansionSnapshot(fixtureName: "PersistentModelBasic")
  }
}
