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

@main
struct CDETool: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "cde-tool",
    abstract: "CoreDataEvolution tooling CLI.",
    subcommands: [
      GenerateCommand.self,
      ValidateCommand.self,
      InspectCommand.self,
      BootstrapConfigCommand.self,
      InitConfigCommand.self,
    ]
  )
}
