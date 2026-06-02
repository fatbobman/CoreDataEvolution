#if compiler(>=6.2)
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

  @preconcurrency import CoreDataEvolution
  import Testing

  @Composition
  struct ObservationFieldMapProfile {
    var nickname: String = ""
  }

  @objc(ObservationFieldMapParent)
  @PersistentModel(observation: .mainActor)
  final class ObservationFieldMapParent: NSManagedObject {
    @Attribute(persistentName: "display_name")
    var name: String = ""

    @Relationship(inverse: "favoriteOf", deleteRule: .nullify)
    var favorite: ObservationFieldMapChild?

    @Relationship(inverse: "parent", deleteRule: .nullify)
    var children: Set<ObservationFieldMapChild>

    @Relationship(inverse: "orderedParent", deleteRule: .nullify)
    var orderedChildren: [ObservationFieldMapChild]

    @Attribute(persistentName: "profileStorage", storageMethod: .composition)
    var profile: ObservationFieldMapProfile? = nil

    @Attribute(.transient)
    var transientNote: String = ""
  }

  @objc(ObservationFieldMapChild)
  @PersistentModel
  final class ObservationFieldMapChild: NSManagedObject {
    @Relationship(inverse: "favorite", deleteRule: .nullify)
    var favoriteOf: ObservationFieldMapParent?

    @Relationship(inverse: "children", deleteRule: .nullify)
    var parent: ObservationFieldMapParent?

    @Relationship(inverse: "orderedChildren", deleteRule: .nullify)
    var orderedParent: ObservationFieldMapParent?
  }

  @Suite("Observation Field Map")
  struct ObservationFieldMapTests {
    @Test("generated field map fans out Core Data keys")
    func generatedFieldMapFansOutCoreDataKeys() {
      guard #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *) else {
        return
      }

      #expect(paths(for: ["display_name"]) == ["name"])
      #expect(paths(for: ["favorite"]) == ["favorite"])
      #expect(paths(for: ["children"]) == ["children", "childrenCount"])
      #expect(paths(for: ["orderedChildren"]) == ["orderedChildren", "orderedChildrenCount"])
      #expect(paths(for: ["profileStorage"]) == ["profile"])
      #expect(paths(for: ["transientNote"]).isEmpty)
      #expect(paths(for: ["unknown"]).isEmpty)

      let combined = paths(for: ["display_name", "children", "profileStorage", "unknown"])
      #expect(Set(combined) == ["name", "children", "childrenCount", "profile"])

      let children = ObservationFieldMapParent.__cdObservationFieldSet(
        forCoreDataKeys: ["children"]
      )
      #expect(children.count == 2)
      #expect(ObservationFieldMapParent.__cdObservationKeyPaths(for: children).count == 2)
    }

    private func paths(for coreDataKeys: [String]) -> [String] {
      let fieldSet = ObservationFieldMapParent.__cdObservationFieldSet(
        forCoreDataKeys: coreDataKeys
      )
      return ObservationFieldMapParent.__cdObservationSwiftPaths(for: fieldSet)
    }
  }

#endif
