import Foundation
import Testing

@Suite("Integer 64 CLI")
struct Integer64CLITests {
  @Test("generate and validate share the integer representation option")
  func integerRepresentationFlow() throws {
    let model = try makeMinimalSourceModelFixture()
    defer { try? FileManager.default.removeItem(at: model.deletingLastPathComponent()) }
    let contentsURL = model.appendingPathComponent("contents")
    let xml = try String(contentsOf: contentsURL, encoding: .utf8)
      .replacingOccurrences(of: "attributeType=\"String\"", with: "attributeType=\"Integer 64\"")
    try xml.write(to: contentsURL, atomically: true, encoding: .utf8)
    let output = model.deletingLastPathComponent().appendingPathComponent("Generated")
    let common = ["--model-path", model.path, "--module-name", "App"]
    let generated = try runTool(
      ["generate"] + common + [
        "--output-dir", output.path, "--integer64-swift-type", "Int",
      ])
    #expect(generated.exitCode == 0, "\(generated.stderr)")
    guard generated.exitCode == 0 else { return }
    let file = output.appendingPathComponent("Item+CoreDataEvolution.swift")
    let source = try String(contentsOf: file, encoding: .utf8)
    #expect(source.contains("var name: Int?"))
    let validation = ["validate"] + common + ["--source-dir", output.path]
    let exact = try runTool(validation + ["--integer64-swift-type", "Int", "--level", "exact"])
    #expect(exact.exitCode == 0)
    let defaultCheck = try runTool(validation)
    #expect(defaultCheck.exitCode != 0)
    try source.replacingOccurrences(of: "var name: Int?", with: "var name: Int64?")
      .write(to: file, atomically: true, encoding: .utf8)
    #expect(try runTool(validation + ["--integer64-swift-type", "Int"]).exitCode == 0)
    #expect(
      try runTool(validation + ["--integer64-swift-type", "Int", "--level", "exact"]).exitCode != 0)
    #expect(try runTool(validation + ["--integer64-swift-type", "Int32"]).exitCode != 0)
  }
}
