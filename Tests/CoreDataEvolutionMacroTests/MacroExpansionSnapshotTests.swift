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
  @Test("Composition basic snapshot")
  func compositionBasicSnapshot() throws {
    try MacroTestSupport.assertExpansionSnapshot(fixtureName: "CompositionBasic")
  }
}
