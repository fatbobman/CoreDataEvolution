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

import Foundation

struct CDEToolConfigTemplate: Codable {
  let schemaVersion: Int
  let generate: GenerateTemplate?
  let validate: ValidateTemplate?

  enum CodingKeys: String, CodingKey {
    case schemaVersion = "$schemaVersion"
    case generate
    case validate
  }
}

struct GenerateTemplate: Codable {
  let modelPath: String
  let modelVersion: String?
  let momcBin: String?
  let outputDir: String
  let moduleName: String
  let accessLevel: String?
  let singleFile: Bool?
  let splitByEntity: Bool?
  let overwrite: String?
  let cleanStale: Bool?
  let dryRun: Bool?
  let format: String?
  let headerTemplate: String?
  let generateInit: Bool?
  let relationshipSetterPolicy: String?
  let relationshipCountPolicy: String?
  let defaultDecodeFailurePolicy: String?
}

struct ValidateTemplate: Codable {
  let modelPath: String
  let modelVersion: String?
  let sourceDir: String
  let moduleName: String
  let include: [String]?
  let exclude: [String]?
  let level: String?
  let report: String?
  let failOnWarning: Bool?
  let maxIssues: Int?
}

func makeTemplate(preset: InitConfigCommand.Preset) -> CDEToolConfigTemplate {
  switch preset {
  case .minimal:
    return .init(
      schemaVersion: 1,
      generate: .init(
        modelPath: "Models/AppModel.xcdatamodeld",
        modelVersion: nil,
        momcBin: nil,
        outputDir: "Generated/CoreDataEvolution",
        moduleName: "AppModels",
        accessLevel: nil,
        singleFile: nil,
        splitByEntity: nil,
        overwrite: nil,
        cleanStale: nil,
        dryRun: nil,
        format: nil,
        headerTemplate: nil,
        generateInit: nil,
        relationshipSetterPolicy: nil,
        relationshipCountPolicy: nil,
        defaultDecodeFailurePolicy: nil
      ),
      validate: .init(
        modelPath: "Models/AppModel.xcdatamodeld",
        modelVersion: nil,
        sourceDir: "Sources/AppModels",
        moduleName: "AppModels",
        include: nil,
        exclude: nil,
        level: nil,
        report: nil,
        failOnWarning: nil,
        maxIssues: nil
      )
    )
  case .full:
    return .init(
      schemaVersion: 1,
      generate: .init(
        modelPath: "Models/AppModel.xcdatamodeld",
        modelVersion: nil,
        momcBin: nil,
        outputDir: "Generated/CoreDataEvolution",
        moduleName: "AppModels",
        accessLevel: "internal",
        singleFile: false,
        splitByEntity: true,
        overwrite: "none",
        cleanStale: false,
        dryRun: false,
        format: "swift-format",
        headerTemplate: nil,
        generateInit: false,
        relationshipSetterPolicy: "warning",
        relationshipCountPolicy: "none",
        defaultDecodeFailurePolicy: "fallbackToDefaultValue"
      ),
      validate: .init(
        modelPath: "Models/AppModel.xcdatamodeld",
        modelVersion: nil,
        sourceDir: "Sources/AppModels",
        moduleName: "AppModels",
        include: [],
        exclude: [],
        level: "quick",
        report: "text",
        failOnWarning: false,
        maxIssues: 200
      )
    )
  }
}

func encodeJSON<T: Encodable>(_ value: T) throws -> Data {
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
  return try encoder.encode(value)
}
