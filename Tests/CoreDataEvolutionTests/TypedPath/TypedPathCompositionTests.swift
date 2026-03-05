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

import CoreDataEvolution
import Testing

@Suite("TypedPath Composition Tests")
struct TypedPathCompositionTests {
  @Test func compositionTypeProvidesStaticFieldTable() throws {
    #expect(PathLocationComposition.__cdCompositionFieldTable["x"]?.swiftPath == ["x"])
    #expect(PathLocationComposition.__cdCompositionFieldTable["y"]?.persistentPath == ["y"])
  }

  @Test func mainModelCanBuildCompositionEntriesWithoutReflection() throws {
    let entries = CDCompositionTableBuilder.makeModelFieldEntries(
      modelSwiftPathPrefix: ["location"],
      modelPersistentPathPrefix: ["location"],
      composition: PathLocationComposition.self
    )
    #expect(entries["location.x"]?.persistentPath == ["location", "x"])
    #expect(entries["location.y"]?.swiftPath == ["location", "y"])
  }
}
