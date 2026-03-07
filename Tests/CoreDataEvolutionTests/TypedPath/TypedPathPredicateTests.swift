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
import Foundation
import Testing

@Suite("TypedPath Predicate Tests")
struct TypedPathPredicateTests {
  @Test func pathDslSupportsNormalAndCompositionForms() throws {
    #expect(PathItemModel.path.title.swiftPathKey == "title")
    #expect(PathItemModel.path.title.raw == "title")
    #expect(PathItemModel.path.magnitude.richter.swiftPathKey == "magnitude.richter")
    #expect(PathItemModel.path.magnitude.richter.raw == "magnitude.richter")
    #expect(PathItemModel.path.tags.any.name.persistentPathKey == "tags.tag_name")
    #expect(PathItemModel.path.tags.any.name.raw == "tags.tag_name")
  }

  @Test func toManyAnyBuildsPredicate() throws {
    let predicate = PathItemModel.path.tags.any.name.equals("Swift")
    #expect(predicate.predicateFormat.contains("ANY tags.tag_name =="))
  }

  @Test func toManyAllBuildsPredicate() throws {
    let predicate = PathItemModel.path.tags.all.score.greaterThan(80)
    #expect(predicate.predicateFormat.contains("NOT ANY tags.score <="))
  }

  @Test func toManyNoneBuildsPredicate() throws {
    let predicate = PathItemModel.path.tags.none.name.contains("legacy")
    #expect(predicate.predicateFormat.contains("NOT ANY tags.tag_name CONTAINS"))
  }

  @Test func toManyNoneMatchesExplicitNotAny() throws {
    let fromDsl = PathItemModel.path.tags.none.name.equals("Swift")
    let explicit = NSCompoundPredicate(
      notPredicateWithSubpredicate: NSPredicate(
        format: "ANY %K == %@",
        argumentArray: ["tags.tag_name", "Swift"]
      )
    )
    #expect(fromDsl.predicateFormat == explicit.predicateFormat)
  }

  @Test func toManyAndNormalFieldsCanComposePredicate() throws {
    let predicate = NSCompoundPredicate(
      andPredicateWithSubpredicates: [
        PathItemModel.path.tags.any.name.equals("Swift"),
        PathItemModel.path.title.contains("Core Data"),
      ]
    )
    #expect(predicate.predicateFormat.contains("ANY tags.tag_name =="))
    #expect(predicate.predicateFormat.contains("title CONTAINS"))
  }

  @Test func rawEqualsBuildsPredicateFromRawValue() throws {
    let predicate = PathItemModel.path.status.equals(PathItemStatus.active)
    #expect(predicate.predicateFormat.contains("status_raw =="))
    #expect(predicate.predicateFormat.contains("active"))
  }

  @Test func rawNotEqualsBuildsPredicateFromRawValue() throws {
    let predicate = PathItemModel.path.status.notEquals(PathItemStatus.archived)
    #expect(predicate.predicateFormat.contains("status_raw !="))
    #expect(predicate.predicateFormat.contains("archived"))
  }
}
