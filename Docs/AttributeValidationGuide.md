# Attribute Validation

`@Attribute` can mirror Core Data's built-in number, string, and date validation rules:

```swift
@objc(Item)
@PersistentModel
final class Item: NSManagedObject {
  @Attribute(persistentName: "name", minLength: 1, maxLength: 80, regex: #".*\S.*"#)
  var title: String?

  @Attribute(min: 0, max: 255)
  var count: Int?

  @Attribute(
    minDate: Date(timeIntervalSince1970: 0),
    maxDate: Date(timeIntervalSince1970: 2_000_000_000)
  )
  var timestamp: Date?
}
```

These rules describe model constraints. Core Data validates them during `context.save()` or an
explicit validation call. Generated setters preserve normal Core Data editing behavior: a value
can temporarily be invalid while a unit of work is in progress.

## Production Model Mapping

The production `.xcdatamodeld` remains the schema authority. Adding a Swift annotation does not
modify or add rules to a loaded production model. Configure the same constraints in Xcode's model
editor, then run `cde-tool validate` to check the declarations against that model.

Rules belong to the persistent attribute. In the example, `title` maps to the model's `name`
attribute; validation errors identify `name`, not `title`.

`cde-tool generate` reads the selected model through `momc`, extracts the built-in validation
predicates, and emits matching annotations. Generation and validation use the constraints
actually present in the compiled model, including normalization performed by `momc`.

## Supported Rules

| Arguments | Swift attribute type | Semantics |
| --- | --- | --- |
| `min`, `max` | `Int`, `Int16`, `Int32`, `Int64`, `Float`, `Double`, `Decimal` | Inclusive numeric bounds |
| `minLength`, `maxLength` | `String` | Inclusive Core Data/Foundation string lengths |
| `regex` | `String` | ICU pattern, using Core Data's full-string `MATCHES` semantics |
| `minDate`, `maxDate` | `Date` | Inclusive fixed date bounds |

Only `.default` storage is supported. Optional attributes allow `nil`; validation rules do not
make an optional property required. String lengths follow Core Data's NSString behavior, which
can differ from Swift's grapheme-cluster `String.count` for emoji and combining characters.

Numeric arguments must be finite decimal literals within Foundation Decimal's representable
precision and range, with optional signs, underscores, decimal points, or exponents. The macro
records decimal bounds without converting them through `Double`,
so large `Int64` bounds remain exact. `minLength` and `maxLength` must be non-negative integer
literals. A minimum must not exceed its maximum.

Date arguments accept `.distantPast`, `.distantFuture`,
`Date(timeIntervalSince1970: <numeric literal>)`, and
`Date(timeIntervalSinceReferenceDate: <numeric literal>)`, including qualified `Foundation.Date`
spellings. Dynamic expressions such as `Date()` or named constants are rejected: tooling cannot
resolve them without executing user code, and a moving bound would not reproduce a fixed model
constraint. `nil` means the rule is absent.

## Regex Validation in cde-tool

Use an ICU pattern string, not a Swift `Regex` literal. Escaped, raw, Unicode-escaped, and
non-interpolated multiline Swift strings are decoded by SwiftParser before comparison:

```swift
@Attribute(regex: ".*\\S.*")
@Attribute(regex: #".*\S.*"#)
@Attribute(regex: ".*\u{5c}S.*")
```

All three spellings have the same decoded pattern and pass `conformance` validation against the
same model pattern. Significant pattern content is preserved: whitespace, inline flags, anchors,
backslashes, and Unicode scalars are not rewritten, stripped, or normalized.

After decoding, `conformance` compares the pattern's UTF-8 bytes exactly with the model's pattern.
It does not attempt to prove that different regular expressions accept the same language. For example,
replacing `\S` with `[^\s]` reports a mismatch even if the patterns happen to match the same inputs.
Update the production model and source together, or use `generate` to regenerate the declaration.

`exact` additionally checks canonical generated file text. A raw-string rewrite can therefore pass
`conformance` while failing `exact`. Leave tool-managed files in the generated spelling when using
`exact`.

Invalid ICU patterns, interpolated strings, named pattern constants, and Swift regex literals
produce diagnostics. Missing, added, and changed rules are all checked. Validation-rule differences
are not automatically fixed. Fixes for other annotation metadata are also withheld when rewriting
the annotation would change or discard validation rules.

## Pure-Code Test Models and Coverage

`makeRuntimeModel` / `makeRuntimeTest` install supported rules before the model is used by a store.
They use Core Data's own predicates and built-in numeric validation warning codes, so tests can
check save failures, multiple validation errors, and persistent attribute keys.

The package compares these behaviors with a real `momc`-compiled model on SQLite, including insert,
update, nil, Unicode strings, numeric/date boundaries, large integers, and decimal values. This
does not promise model hash, migration, localization, or every platform/toolchain detail is
identical.

The following cases require real-model integration tests:

- Rules only present in `.xcdatamodeld` and absent from Swift metadata. A pure-code builder cannot
  discover those rules without the production model; run `cde-tool validate` to detect drift.
- Model predicates or custom validation warnings outside the supported built-in subset.
- Model constraints on `.raw`, `.codable`, `.transformed`, or `.composition` storage. The Swift
  value and its persisted representation may differ, and composition has a different test layout.
- Model behavior such as external binary storage, Spotlight indexing, and preservation on deletion,
  which is not represented in the current runtime schema.

Unsupported declared rules fail macro validation or runtime model construction instead of being
silently skipped. Tooling reports model constraints it cannot represent, and refuses generation
that would lose them. Custom `validate<Key>`, `validateForInsert`, and `validateForUpdate` methods
remain ordinary Core Data APIs; this feature does not generate or analyze those methods.

For runtime schema setup, see [PersistentModelGuide.md](./PersistentModelGuide.md). For validation
levels and tooling workflow, see [CDEToolGuide.md](./CDEToolGuide.md).
