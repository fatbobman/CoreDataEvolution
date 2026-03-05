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

struct InitConfigCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "init-config",
    abstract: "Export a default JSON config template."
  )

  @Option(name: .long, help: "Output config file path.")
  var output: String?

  @Flag(name: .long, help: "Print config JSON to stdout.")
  var stdout = false

  @Flag(name: .long, help: "Overwrite existing config file.")
  var force = false

  @Option(name: .long, help: "Template preset: minimal/full.")
  var preset: Preset = .full

  mutating func run() throws {
    if stdout, output != nil {
      try failUser(
        code: .configConflict,
        message: "--output and --stdout cannot be used together."
      )
    }

    let template = makeDefaultConfigTemplate(preset: preset.toolingPreset)
    let data = try encodeToolingJSON(template)

    if stdout {
      guard let text = String(data: data, encoding: .utf8) else {
        try failInternal(
          code: .jsonEncodeFailed,
          message: "failed to encode config template as UTF-8."
        )
      }
      print(text)
      return
    }

    let outputPath = output ?? "cde-tool.json"
    let url = URL(fileURLWithPath: outputPath)
    let fm = FileManager.default
    let directory = url.deletingLastPathComponent()
    var isDirectory: ObjCBool = false
    if fm.fileExists(atPath: directory.path, isDirectory: &isDirectory) == false
      || isDirectory.boolValue == false
    {
      try failUser(
        code: .outputDirMissing,
        message: "output directory does not exist: '\(directory.path)'."
      )
    }
    if fm.fileExists(atPath: url.path), force == false {
      try failUser(
        code: .configExists,
        message: "config file already exists at '\(url.path)'. Use --force to overwrite."
      )
    }

    do {
      try data.write(to: url, options: [.atomic])
      print("wrote config template to \(url.path)")
    } catch {
      try failUser(
        code: .writeDenied,
        message: "cannot write config file to '\(url.path)' (\(error.localizedDescription))."
      )
    }
  }
}

extension InitConfigCommand {
  enum Preset: String, ExpressibleByArgument {
    case minimal
    case full

    var toolingPreset: ToolingConfigTemplatePreset {
      switch self {
      case .minimal:
        return .minimal
      case .full:
        return .full
      }
    }
  }
}
