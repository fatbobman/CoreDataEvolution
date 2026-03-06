//
//  ------------------------------------------------
//  Original project: CoreDataEvolution
//  Created on 2026/3/6 by Fatbobman(东坡肘子)
//  X: @fatbobman
//  Mastodon: @fatbobman@mastodon.social
//  GitHub: @fatbobman
//  Blog: https://fatbobman.com
//  ------------------------------------------------
//  Copyright © 2024-present Fatbobman. All rights reserved.

import CoreDataEvolutionToolingCore
import Foundation

/// Creates temporary source-model fixtures for tooling tests.
///
/// The repository's integration model keeps Xcode code generation enabled for unrelated test
/// coverage. Tooling tests need the opposite contract, so they copy the model and strip
/// `codeGenerationType` to emulate Xcode's Manual/None serialization.
func makeToolingSourceModelFixture(
  filePath: String = #filePath,
  mutateContents: ((String) -> String)? = nil
) throws -> URL {
  let repositoryRoot = try findToolingRepositoryRoot(filePath: filePath)
  let sourcePackageURL =
    repositoryRoot
    .appendingPathComponent("Models")
    .appendingPathComponent("Integration")
    .appendingPathComponent("CoreDataEvolutionIntegrationModel.xcdatamodeld")

  let temporaryPackageURL = FileManager.default.temporaryDirectory
    .appendingPathComponent("CoreDataEvolutionToolingCoreTests", isDirectory: true)
    .appendingPathComponent(UUID().uuidString, isDirectory: true)
    .appendingPathComponent("CoreDataEvolutionIntegrationModel.xcdatamodeld", isDirectory: true)

  try FileManager.default.createDirectory(
    at: temporaryPackageURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
  )
  try FileManager.default.copyItem(at: sourcePackageURL, to: temporaryPackageURL)

  let contentsURL =
    temporaryPackageURL
    .appendingPathComponent("CoreDataEvolutionIntegrationModel.xcdatamodel")
    .appendingPathComponent("contents")
  var contents = try String(contentsOf: contentsURL, encoding: .utf8)
  contents = contents.replacingOccurrences(
    of: #"\s*codeGenerationType="[^"]+""#,
    with: "",
    options: .regularExpression
  )
  contents = contents.replacingOccurrences(
    of: #"<attribute name="name" attributeType="String" defaultValueString=""/>"#,
    with: """
      <attribute name="name" attributeType="String" defaultValueString=""/>
            <uniquenessConstraints>
                <uniquenessConstraint>
                    <constraint value="name"/>
                </uniquenessConstraint>
            </uniquenessConstraints>
      """
  )
  if let mutateContents {
    contents = mutateContents(contents)
  }
  try contents.write(to: contentsURL, atomically: true, encoding: .utf8)

  return temporaryPackageURL
}

func findToolingRepositoryRoot(filePath: String = #filePath) throws -> URL {
  var currentURL = URL(fileURLWithPath: filePath).deletingLastPathComponent()
  while currentURL.path != "/" {
    if FileManager.default.fileExists(
      atPath: currentURL.appendingPathComponent("Package.swift").path)
    {
      return currentURL
    }
    currentURL = currentURL.deletingLastPathComponent()
  }

  throw ToolingFailure.runtime(
    .internalError,
    "failed to locate repository root from '\(filePath)'."
  )
}
