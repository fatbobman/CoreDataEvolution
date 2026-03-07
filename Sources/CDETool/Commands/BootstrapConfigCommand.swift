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

  @Option(
    name: .long,
    help:
      "Path to source model (.xcdatamodeld/.xcdatamodel). Compiled .mom/.momd inputs are not supported."
  )
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
      emitInfo(text)
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

    let templateForOutput = relocateBootstrapTemplate(
      result.template,
      outputURL: url,
      currentDirectoryURL: URL(
        fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
    )

    do {
      let data = try encodeToolingJSON(templateForOutput)
      try data.write(to: url, options: [.atomic])
      emitWriteSuccess(kind: "bootstrap config", path: url.path)
    } catch let failure as ToolingFailure {
      try fail(failure)
    } catch {
      try failUser(
        code: .writeDenied,
        message: "cannot write config file to '\(url.path)' (\(error.localizedDescription))."
      )
    }
  }
}

private func relocateBootstrapTemplate(
  _ template: ToolingConfigTemplate,
  outputURL: URL,
  currentDirectoryURL: URL
) -> ToolingConfigTemplate {
  let configDirectoryURL = outputURL.deletingLastPathComponent()

  return .init(
    schemaVersion: template.schemaVersion,
    generate: template.generate.map { generate in
      .init(
        modelPath: relativizeBootstrapPath(
          generate.modelPath,
          configDirectoryURL: configDirectoryURL,
          currentDirectoryURL: currentDirectoryURL
        ),
        modelVersion: generate.modelVersion,
        momcBin: relativizeOptionalBootstrapPath(
          generate.momcBin,
          configDirectoryURL: configDirectoryURL,
          currentDirectoryURL: currentDirectoryURL
        ),
        outputDir: relativizeBootstrapPath(
          generate.outputDir,
          configDirectoryURL: configDirectoryURL,
          currentDirectoryURL: currentDirectoryURL
        ),
        moduleName: generate.moduleName,
        typeMappings: generate.typeMappings,
        attributeRules: generate.attributeRules,
        accessLevel: generate.accessLevel,
        singleFile: generate.singleFile,
        splitByEntity: generate.splitByEntity,
        overwrite: generate.overwrite,
        cleanStale: generate.cleanStale,
        dryRun: generate.dryRun,
        format: generate.format,
        headerTemplate: relativizeOptionalBootstrapPath(
          generate.headerTemplate,
          configDirectoryURL: configDirectoryURL,
          currentDirectoryURL: currentDirectoryURL
        ),
        emitExtensionStubs: generate.emitExtensionStubs,
        generateInit: generate.generateInit,
        relationshipSetterPolicy: generate.relationshipSetterPolicy,
        relationshipCountPolicy: generate.relationshipCountPolicy,
        defaultDecodeFailurePolicy: generate.defaultDecodeFailurePolicy
      )
    },
    validate: template.validate.map { validate in
      .init(
        modelPath: relativizeBootstrapPath(
          validate.modelPath,
          configDirectoryURL: configDirectoryURL,
          currentDirectoryURL: currentDirectoryURL
        ),
        modelVersion: validate.modelVersion,
        momcBin: relativizeOptionalBootstrapPath(
          validate.momcBin,
          configDirectoryURL: configDirectoryURL,
          currentDirectoryURL: currentDirectoryURL
        ),
        sourceDir: relativizeBootstrapPath(
          validate.sourceDir,
          configDirectoryURL: configDirectoryURL,
          currentDirectoryURL: currentDirectoryURL
        ),
        moduleName: validate.moduleName,
        typeMappings: validate.typeMappings,
        attributeRules: validate.attributeRules,
        accessLevel: validate.accessLevel,
        singleFile: validate.singleFile,
        splitByEntity: validate.splitByEntity,
        headerTemplate: relativizeOptionalBootstrapPath(
          validate.headerTemplate,
          configDirectoryURL: configDirectoryURL,
          currentDirectoryURL: currentDirectoryURL
        ),
        generateInit: validate.generateInit,
        relationshipSetterPolicy: validate.relationshipSetterPolicy,
        relationshipCountPolicy: validate.relationshipCountPolicy,
        defaultDecodeFailurePolicy: validate.defaultDecodeFailurePolicy,
        include: validate.include,
        exclude: validate.exclude,
        level: validate.level,
        report: validate.report,
        failOnWarning: validate.failOnWarning,
        maxIssues: validate.maxIssues
      )
    }
  )
}

private func relativizeBootstrapPath(
  _ path: String,
  configDirectoryURL: URL,
  currentDirectoryURL: URL
) -> String {
  let absoluteURL: URL
  if (path as NSString).isAbsolutePath {
    absoluteURL = URL(fileURLWithPath: path)
  } else {
    absoluteURL = currentDirectoryURL.appendingPathComponent(path)
  }

  let normalizedAbsoluteURL = absoluteURL.standardizedFileURL
  let normalizedConfigDirectoryURL = configDirectoryURL.standardizedFileURL
  let absoluteComponents = normalizedAbsoluteURL.pathComponents
  let baseComponents = normalizedConfigDirectoryURL.pathComponents
  let sharedCount = zip(absoluteComponents, baseComponents)
    .prefix { $0 == $1 }
    .count
  let relativeComponents =
    Array(repeating: "..", count: baseComponents.count - sharedCount)
    + absoluteComponents.dropFirst(sharedCount)

  guard relativeComponents.isEmpty == false else {
    return "."
  }

  return NSString.path(withComponents: relativeComponents)
}

private func relativizeOptionalBootstrapPath(
  _ path: String?,
  configDirectoryURL: URL,
  currentDirectoryURL: URL
) -> String? {
  guard let path else { return nil }
  return relativizeBootstrapPath(
    path,
    configDirectoryURL: configDirectoryURL,
    currentDirectoryURL: currentDirectoryURL
  )
}
