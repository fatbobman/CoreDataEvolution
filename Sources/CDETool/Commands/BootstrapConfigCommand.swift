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

import ArgumentParser
import CoreDataEvolutionToolingCore
import Foundation

struct BootstrapConfigCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "bootstrap-config",
    abstract: "Generate an editable config scaffold from a Core Data model."
  )

  @Option(name: .long, help: "Path to source model (.xcdatamodeld/.xcdatamodel).")
  var modelPath: String

  @Option(name: .long, help: "Specific model version name. Defaults to current/latest.")
  var modelVersion: String?

  @Option(name: .long, help: "Path to momc binary.")
  var momcBin: String?

  @Option(name: .long, help: "Swift module name for generated code.")
  var moduleName: String = "AppModels"

  @Option(name: .long, help: "Default output directory to write generated files.")
  var outputDir: String = "Generated/CoreDataEvolution"

  @Option(name: .long, help: "Default source directory used by validate.")
  var sourceDir: String = "Sources/AppModels"

  @Option(name: .long, help: "Output config file path.")
  var output: String?

  @Flag(name: .long, help: "Print config JSON to stdout.")
  var stdout = false

  @Flag(name: .long, help: "Overwrite existing config file.")
  var force = false

  mutating func run() throws {
    if stdout, output != nil {
      try failUser(
        code: .configConflict,
        message: "--output and --stdout cannot be used together."
      )
    }

    let result: BootstrapConfigResult
    do {
      result = try BootstrapConfigService.run(
        .init(
          modelPath: modelPath,
          modelVersion: modelVersion,
          momcBin: momcBin,
          moduleName: moduleName,
          outputDir: outputDir,
          sourceDir: sourceDir
        )
      )
    } catch let failure as ToolingFailure {
      try fail(failure)
    }

    if stdout {
      guard let text = String(data: result.jsonData, encoding: .utf8) else {
        try failInternal(
          code: .jsonEncodeFailed,
          message: "failed to encode bootstrap config as UTF-8."
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
      try result.jsonData.write(to: url, options: [.atomic])
      print("wrote bootstrap config to \(url.path)")
    } catch {
      try failUser(
        code: .writeDenied,
        message: "cannot write config file to '\(url.path)' (\(error.localizedDescription))."
      )
    }
  }
}
