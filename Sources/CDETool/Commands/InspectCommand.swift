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

import ArgumentParser
import CoreDataEvolutionToolingCore
import Foundation

struct InspectCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "inspect",
    abstract: "Inspect parsed model IR (work in progress)."
  )

  @Option(name: .long, help: "Path to source model (.xcdatamodeld/.xcdatamodel).")
  var modelPath: String

  @Option(name: .long, help: "Specific model version name. Defaults to current/latest.")
  var modelVersion: String?

  @Option(name: .long, help: "Path to momc binary.")
  var momcBin: String?

  @Option(name: .long, help: "Path to JSON config file.")
  var config: String?

  mutating func run() throws {
    let request: InspectRequest

    do {
      if let config {
        let template = try loadToolingConfigTemplate(
          at: URL(fileURLWithPath: config)
        )
        guard let generate = template.generate else {
          try failUser(
            code: .configInvalid,
            message: "inspect requires a generate section in the config file."
          )
        }
        request = .init(
          config: generate,
          modelPathOverride: modelPath,
          modelVersionOverride: modelVersion,
          momcBinOverride: momcBin
        )
      } else {
        request = .init(
          modelPath: modelPath,
          modelVersion: modelVersion,
          momcBin: momcBin
        )
      }
    } catch let failure as ToolingFailure {
      try fail(failure)
    }

    let result: InspectResult
    do {
      result = try InspectService.run(request)
    } catch let failure as ToolingFailure {
      try fail(failure)
    }

    guard let text = String(data: result.jsonData, encoding: .utf8) else {
      try failInternal(
        code: .jsonEncodeFailed,
        message: "failed to encode inspect IR as UTF-8."
      )
    }

    print(text)

    for diagnostic in result.diagnostics {
      fputs("\(diagnostic.severity.rawValue): \(diagnostic.message)\n", stderr)
      if let hint = diagnostic.hint {
        fputs("hint: \(hint)\n", stderr)
      }
    }
  }
}
