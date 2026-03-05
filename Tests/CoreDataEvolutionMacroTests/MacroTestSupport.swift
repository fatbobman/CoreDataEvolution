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

import CoreDataEvolutionMacros
import Foundation
import SwiftBasicFormat
import SwiftParser
import SwiftSyntax
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros

struct MacroExpansionResult {
  let expandedSource: String
  let formattedExpandedSource: String
  let diagnostics: [String]
}

enum MacroTestSupportError: Error, CustomStringConvertible {
  case unexpectedDiagnostics(fixtureName: String, diagnostics: [String])
  case missingSnapshot(path: String)
  case snapshotMismatch(snapshotName: String)

  var description: String {
    switch self {
    case .unexpectedDiagnostics(let fixtureName, let diagnostics):
      return
        "Unexpected diagnostics for fixture \(fixtureName):\n\(diagnostics.joined(separator: "\n"))"
    case .missingSnapshot(let path):
      return "Missing snapshot at \(path). Re-run tests with UPDATE_SNAPSHOTS=1 to create it."
    case .snapshotMismatch(let snapshotName):
      return "Snapshot mismatch at \(snapshotName). Re-run tests with UPDATE_SNAPSHOTS=1 to update."
    }
  }
}

enum MacroTestSupport {
  static let indentationWidth: Trivia = .spaces(2)

  static let macroSpecs: [String: MacroSpec] = [
    "PersistentModel": MacroSpec(
      type: PersistentModelMacro.self,
      conformances: ["PersistentEntity"]
    ),
    "Attribute": MacroSpec(
      type: AttributeMacro.self
    ),
    "Composition": MacroSpec(
      type: CompositionMacro.self,
      conformances: ["CDCompositionPathProviding", "CDCompositionValueCodable"]
    ),
    "Ignore": MacroSpec(
      type: IgnoreMacro.self
    ),
    "_CDRelationship": MacroSpec(
      type: RelationshipMacro.self
    ),
  ]

  static func expandFixture(named fixtureName: String) throws -> MacroExpansionResult {
    try expand(
      source: fixtureSource(named: fixtureName),
      fileName: "\(fixtureName).swift"
    )
  }

  static func expand(source: String, fileName: String = "test.swift") throws -> MacroExpansionResult
  {
    let sourceFile = Parser.parse(source: source)
    let context = BasicMacroExpansionContext(
      sourceFiles: [
        sourceFile: .init(moduleName: "CoreDataEvolutionMacroTests", fullFilePath: fileName)
      ]
    )

    func contextGenerator(_ syntax: Syntax) -> BasicMacroExpansionContext {
      BasicMacroExpansionContext(
        sharingWith: context,
        lexicalContext: syntax.allMacroLexicalContexts()
      )
    }

    let expanded = sourceFile.expand(
      macroSpecs: macroSpecs,
      contextGenerator: contextGenerator,
      indentationWidth: indentationWidth
    )
    let format = BasicFormat(indentationWidth: indentationWidth)

    return MacroExpansionResult(
      expandedSource: trimmedSource(expanded.description),
      formattedExpandedSource: trimmedSource(expanded.formatted(using: format).description),
      diagnostics: context.diagnostics.map { String(describing: $0.message) }
    )
  }

  static func assertExpansionSnapshot(fixtureName: String) throws {
    let result = try expandFixture(named: fixtureName)
    if result.diagnostics.isEmpty == false {
      throw MacroTestSupportError.unexpectedDiagnostics(
        fixtureName: fixtureName,
        diagnostics: result.diagnostics
      )
    }

    try assertSnapshot(
      actual: result.expandedSource,
      snapshotURL: snapshotURL(for: fixtureName, suffix: "expanded.swift")
    )
    try assertSnapshot(
      actual: result.formattedExpandedSource,
      snapshotURL: snapshotURL(for: fixtureName, suffix: "formatted.swift")
    )
  }

  static func fixtureSource(named fixtureName: String) throws -> String {
    try String(contentsOf: fixtureURL(for: fixtureName), encoding: .utf8)
  }

  static func fixtureURL(for fixtureName: String) -> URL {
    testDataDirectory
      .appendingPathComponent("Fixtures")
      .appendingPathComponent("\(fixtureName).input")
  }

  static func snapshotURL(for fixtureName: String, suffix: String) -> URL {
    testDataDirectory
      .appendingPathComponent("__Snapshots__")
      .appendingPathComponent("\(fixtureName).\(suffix)")
  }

  static func assertSnapshot(actual: String, snapshotURL: URL) throws {
    let shouldUpdateSnapshots = ProcessInfo.processInfo.environment["UPDATE_SNAPSHOTS"] == "1"

    if shouldUpdateSnapshots {
      try FileManager.default.createDirectory(
        at: snapshotURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      try actual.write(to: snapshotURL, atomically: true, encoding: .utf8)
      return
    }

    guard FileManager.default.fileExists(atPath: snapshotURL.path) else {
      throw MacroTestSupportError.missingSnapshot(path: snapshotURL.path)
    }

    let expected = try String(contentsOf: snapshotURL, encoding: .utf8)
    guard actual == expected else {
      throw MacroTestSupportError.snapshotMismatch(snapshotName: snapshotURL.lastPathComponent)
    }
  }

  private static var testDataDirectory: URL {
    URL(fileURLWithPath: #filePath).deletingLastPathComponent()
  }

  private static func trimmedSource(_ source: String) -> String {
    source
      .replacingOccurrences(of: #"\A[\n\r]+"#, with: "", options: .regularExpression)
      .replacingOccurrences(of: #"[\n\r]+\z"#, with: "", options: .regularExpression)
  }
}
