//
//  ------------------------------------------------
//  Original project: CoreDataEvolution
//  Created on 2026/3/7 by Fatbobman(东坡肘子)
//  X: @fatbobman
//  Mastodon: @fatbobman@mastodon.social
//  GitHub: @fatbobman
//  Blog: https://fatbobman.com
//  ------------------------------------------------
//  Copyright © 2024-present Fatbobman. All rights reserved.

import ArgumentParser

struct VersionCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "version",
    abstract: "Print cde-tool version and build metadata."
  )

  mutating func run() throws {
    print(ToolVersionInfo.detailedDescription)
  }
}
