import Foundation
import SwiftParser
import SwiftSyntax
import Testing

@Suite("Integer width warning macros")
struct IntegerWidthWarningMacroTests {
  @Test("one warning lists only ordinary Int attributes")
  func warningSnapshot() throws {
    try MacroTestSupport.assertExpansionSnapshot(fixtureName: "IntegerWidthWarning")
    let expanded = try MacroTestSupport.expandFixture(named: "IntegerWidthWarning")
    #expect(expanded.diagnostics.isEmpty)
    #expect(expanded.expandedSource.components(separatedBy: "#warning(").count == 2)
    #expect(expanded.expandedSource.contains("Integer 64 attributes: count, sequence, qualified."))
    #expect(expanded.expandedSource.contains("#if _pointerBitWidth(_32)"))
  }

  @Test("models without ordinary Int attributes produce no warning")
  func noIntegerWarning() throws {
    let expanded = try MacroTestSupport.expand(
      source: """
        @objc(WideItem)
        @PersistentModel
        final class WideItem: NSManagedObject {
          var wide: Int64?
          @Ignore var scratch: Int = 0
          @Attribute(storageMethod: .codable) var payload: Int?
          var computed: Int { 0 }
        }
        """)
    #expect(expanded.diagnostics.isEmpty)
    #expect(!expanded.expandedSource.contains("#warning("))
  }

  @Test("warnings are evaluated by the consumer compiler for each target")
  func targetCompilation() throws {
    let expanded = try MacroTestSupport.expandFixture(named: "IntegerWidthWarning")
    let syntax = Parser.parse(source: expanded.expandedSource)
    let model = try #require(
      syntax.statements.compactMap { $0.item.as(ClassDeclSyntax.self) }.first)
    let warning = try #require(
      model.memberBlock.members.compactMap {
        $0.decl.as(IfConfigDeclSyntax.self)
      }.first)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let source = directory.appendingPathComponent("WidthWarning.swift")
    // Compile the actual macro-emitted declaration. It has no library dependency, allowing the
    // same declaration to be checked against both watchOS architectures on a macOS test host.
    try "struct WidthProbe {\n\(warning.description)\n}".write(
      to: source, atomically: true, encoding: .utf8)
    let sdk = try runCompilerTool(["--sdk", "watchos", "--show-sdk-path"])
    #expect(sdk.status == 0)
    let sdkPath = sdk.output.trimmingCharacters(in: .whitespacesAndNewlines)
    var targets = [("arm64_32-apple-watchos6.0", true)]
    let version = try runCompilerTool(["--sdk", "watchos", "--show-sdk-version"])
    #expect(version.status == 0)
    // arm64 watchOS SDK support starts with watchOS 26; retain older Xcode compatibility.
    if let major = Int(
      version.output.trimmingCharacters(in: .whitespacesAndNewlines)
        .split(separator: ".").first ?? ""), major >= 26
    {
      targets.append(("arm64-apple-watchos26.0", false))
    }
    for (target, expectsWarning) in targets {
      let result = try runCompilerTool([
        "swiftc", "-typecheck", "-target", target, "-sdk", sdkPath,
        "-module-cache-path", directory.appendingPathComponent("ModuleCache").path, source.path,
      ])
      #expect(result.status == 0, "\(result.output)")
      let warningLines = result.output.split(separator: "\n").filter {
        $0.contains(": warning: Model 'IntegerWidthItem'")
      }
      #expect(warningLines.count == (expectsWarning ? 1 : 0), "\(result.output)")
      if expectsWarning {
        #expect(result.output.contains("Integer 64 attributes: count, sequence, qualified."))
      }
    }
    let host = try runCompilerTool([
      "swiftc", "-typecheck", "-module-cache-path",
      directory.appendingPathComponent("HostModuleCache").path, source.path,
    ])
    #expect(host.status == 0, "\(host.output)")
    #expect(!host.output.contains("warning:"), "\(host.output)")
  }

  private func runCompilerTool(_ arguments: [String]) throws -> (status: Int32, output: String) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
    process.arguments = arguments
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    try process.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return (process.terminationStatus, String(decoding: data, as: UTF8.self))
  }
}
