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
    #expect(PathItemModel.path.location.x.swiftPathKey == "location.x")
    #expect(PathItemModel.path.location.x.raw == "location.lat")
    #expect(PathItemModel.path.location.y.raw == "location.lng")
    #expect(PathItemModel.path.tags.any.name.persistentPathKey == "tags.tag_name")
    #expect(PathItemModel.path.tags.any.name.raw == "tags.tag_name")
  }

  @Test func toManyAnyBuildsPredicate() throws {
    let predicate = PathItemModel.path.tags.any.name.equals("Swift")
    #expect(predicate.predicateFormat.contains("ANY tags.tag_name =="))
  }

  @Test func toManyAllBuildsPredicate() throws {
    let predicate = PathItemModel.path.tags.all.score.greaterThan(80)
    #expect(predicate.predicateFormat.contains("SUBQUERY(tags, $e, NOT"))
    #expect(predicate.predicateFormat.contains("$e.score > 80"))
    #expect(predicate.predicateFormat.contains(").@count == 0"))
  }

  @Test func toManyNoneBuildsPredicate() throws {
    let predicate = PathItemModel.path.tags.none.name.contains("legacy")
    #expect(
      predicate.predicateFormat
        == #"SUBQUERY(tags, $e, $e.tag_name CONTAINS[cd] "legacy").@count == 0"#)
  }

  @Test func toManyNoneBuildsSubqueryCountPredicate() throws {
    let fromDsl = PathItemModel.path.tags.none.name.equals("Swift")
    #expect(fromDsl.predicateFormat == #"SUBQUERY(tags, $e, $e.tag_name == "Swift").@count == 0"#)
  }

  @Test func toOneRelationNilPredicatesFormat() throws {
    let relation = CoreDataEvolution.CDToOneRelationPath<PathItemModel, PathTagModel>(
      swiftPath: ["category"],
      persistentPath: ["category"]
    )
    #expect(relation.isNil().predicateFormat == #"category == nil"#)
    #expect(relation.isNotNil().predicateFormat == #"category != nil"#)
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
