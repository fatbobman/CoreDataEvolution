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

  @Test func compositionTypeSupportsDictionaryRoundTrip() throws {
    let source = PathLocationComposition(x: 3.2, y: nil)
    let encoded = source.__cdEncodeComposition
    #expect(encoded["x"] as? Double == 3.2)
    #expect(encoded["y"] == nil)

    let decoded = PathLocationComposition.__cdDecodeComposition(from: ["x": 3.2, "y": 8.8])
    #expect(decoded?.x == 3.2)
    #expect(decoded?.y == 8.8)
  }

  @Test func compositionDecodeFailsWhenRequiredFieldMissing() throws {
    let decoded = PathLocationComposition.__cdDecodeComposition(from: ["y": 1.0])
    #expect(decoded == nil)
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
