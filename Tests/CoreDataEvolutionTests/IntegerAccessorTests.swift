import CoreDataEvolution
import Foundation
import Testing

// A controlled backing value exercises the real macro expansion independently of Core Data's
// NSNumber normalization. UInt64.max is unrepresentable as Int even on a 64-bit test host.
private final class IntegerAccessorProbe {
  var stored: NSNumber?

  func value(forKey key: String) -> Any? { stored }
  func setValue(_ value: Any?, forKey key: String) { stored = value as? NSNumber }

  @Attribute
  var optional: Int?

  @Attribute
  var required: Int
}

@Suite("Integer accessors")
struct IntegerAccessorTests {
  @Test("exact integer accessors preserve representable values and absence")
  func representableValues() {
    let probe = IntegerAccessorProbe()
    #expect(probe.optional == nil)
    for value in [Int.min, -1, 0, 1, Int.max] {
      probe.stored = NSNumber(value: value)
      #expect(probe.required == value)
      #expect(probe.optional == value)
      probe.optional = value
      #expect(probe.stored == NSNumber(value: value))
    }
    probe.optional = nil
    #expect(probe.stored == nil)
    // The same exact conversion rejects Integer 64 values outside a 32-bit Int's range.
    #expect(Int32(exactly: NSNumber(value: Int64(Int32.max) + 1)) == nil)
    #expect(Int32(exactly: NSNumber(value: Int64(Int32.min) - 1)) == nil)
  }

  #if compiler(>=6.2) && os(macOS)
    @Test("optional integer accessors report unrepresentable stored values")
    func optionalUnrepresentableValue() async {
      let result = await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) {
        let probe = IntegerAccessorProbe()
        probe.stored = NSNumber(value: UInt64.max)
        _ = probe.optional
      }
      let output = String(decoding: result?.standardErrorContent ?? [], as: UTF8.self)
      #expect(
        output.contains("Stored value for `optional` (optional) cannot be represented as Int"))
    }

    @Test("required integer accessors report unrepresentable stored values")
    func requiredUnrepresentableValue() async {
      let result = await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) {
        let probe = IntegerAccessorProbe()
        probe.stored = NSNumber(value: UInt64.max)
        _ = probe.required
      }
      let output = String(decoding: result?.standardErrorContent ?? [], as: UTF8.self)
      #expect(
        output.contains("Stored value for `required` (required) cannot be represented as Int"))
    }
  #endif
}
