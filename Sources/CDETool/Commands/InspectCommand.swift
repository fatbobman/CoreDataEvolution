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

struct InspectCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "inspect",
    abstract: "Inspect parsed model IR (work in progress)."
  )

  @Option(name: .long, help: "Path to model (.xcdatamodeld/.xcdatamodel/.momd).")
  var modelPath: String

  @Option(name: .long, help: "Specific model version name. Defaults to current/latest.")
  var modelVersion: String?

  @Option(name: .long, help: "Path to JSON config file.")
  var config: String?

  mutating func run() throws {
    try failUser(
      code: .notImplemented,
      message: "inspect is not implemented yet."
    )
  }
}
