# Storage Method Guide

`@Attribute(storageMethod:)` makes Core Data storage choices explicit.

This guide explains:

- why the feature exists
- what each storage method means
- which types each method supports
- what restrictions are intentional in the current implementation
- how this feature relates to `PersistentModel` and typed path mapping

## Why This Exists

In plain Core Data, developers often end up writing manual bridging code to get a better Swift API.

Typical examples:

- expose `Double?`, `Float?`, or other optional scalar values without falling back to `NSNumber?`
- expose an enum instead of a raw string or integer
- expose a custom `Codable` value instead of raw `Data`
- expose a richer value type instead of a transformable payload
- expose a composition-like value instead of manually managing several flattened fields

The traditional solution is usually:

1. keep one stored Core Data field
2. add a computed property on top of it
3. manually encode, decode, or transform in the getter and setter

That works, but it has two recurring problems.

One important pain point comes from the classic `NSManagedObject + @NSManaged` style itself:

- non-optional scalar properties are usually straightforward
- optional scalar properties are much less pleasant to express directly
- developers often fall back to `NSNumber?` or hand-written bridging for values that should really
  be modeled in Swift as `Double?`, `Float?`, `Int?`, and similar types

SwiftData improved this experience by making Swift-facing model declarations feel more natural.
CoreDataEvolution addresses the same problem for Core Data by generating the KVC/KVO-facing access
layer for you, so your source model can stay closer to the Swift types you actually want to use.

### Problem 1: repeated boilerplate

Every model ends up re-implementing the same patterns:

- decode in `get`
- encode in `set`
- fallback behavior on failure
- type conversion rules

This is repetitive and easy to drift across models.

### Problem 2: the typed key/path layer becomes unusable

Once the nicer Swift-facing property becomes a computed bridge, it is no longer a real persisted
attribute.

That means it cannot participate naturally in:

- store-backed `NSSortDescriptor`
- `%K`-based `NSPredicate`
- typed path mapping

This is the same pain point discussed in [TypedPathGuide.md](./TypedPathGuide.md).

## Why Not Just Rely on SwiftData Behavior

SwiftData does support conveniences such as:

- raw-value-backed enums
- `Codable`
- transformable-like storage

But its storage behavior is not always explicit from the declaration alone.

In particular, `Codable` storage is easy to misunderstand:

- it feels high-level in source
- but the underlying persistence layout is not obvious
- and schema evolution can become awkward later

For example, if a `Codable` type expands into multiple stored members or its encoded shape changes
over time, that can become difficult to reason about in a long-lived Core Data schema.

CoreDataEvolution takes a different approach:

- the storage strategy is declared explicitly
- the generated code matches that strategy directly
- the developer chooses the mechanism instead of guessing the framework's internal choice

## The Goal

`storageMethod` exists to make storage semantics explicit and predictable.

Instead of hand-writing conversion boilerplate, you declare what you want:

```swift
@Attribute(storageMethod: .raw)
var status: Status? = .draft
```

or:

```swift
@Attribute(storageMethod: .codable)
var config: ItemConfig? = nil
```

or:

```swift
@Attribute(storageMethod: .composition)
var location: GeoPoint? = nil
```

This gives you:

- explicit source-level intent
- generated getter/setter logic
- consistent validation rules
- compatibility with the macro-generated key/path layer

## The Available Storage Methods

Currently supported:

- `.default`
- `.raw`
- `.codable`
- `.transformed(...)`
- `.composition`

General rule for custom storage:

- `.raw`, `.codable`, `.transformed(...)`, and `.composition` are custom storage methods
- `.codable`, `.transformed(...)`, and `.composition` currently require optional declarations
- for those three storage methods, the only supported explicit default is `nil`
- `.raw` remains the only custom storage path that may still align with a model-backed primitive
  default

## `.default`

`.default` means the Swift property maps directly to a Core Data primitive attribute.

This is the implicit default for primitive types.

Example:

```swift
var title: String = ""
var count: Int64 = 0
var createdAt: Date? = nil
```

### Allowed primitive types

Currently supported types for `.default`:

- `String`
- `Bool`
- `Int16`
- `Int32`
- `Int64`
- `Int`
- `Float`
- `Double`
- `Decimal`
- `Date`
- `Data`
- `UUID`
- `URL`
- optionals of the above

Note about `Int`:

- Core Data does not have a native `Int` attribute kind
- `Int` is supported here as a Swift-facing convenience type
- the underlying Core Data integer storage is still `Integer 16`, `Integer 32`, or `Integer 64`
- if integer width matters, prefer `Int16`, `Int32`, or `Int64` explicitly

### Restrictions

- non-primitive types are not allowed with `.default`
- if the property is non-optional, it must have a default value
- that Swift default value should match the model default value

If you need more detail about model default values, see
[PersistentModelGuide.md](./PersistentModelGuide.md).

## `.raw`

`.raw` is for `RawRepresentable` types, usually enums.

Example:

```swift
enum Status: String {
  case draft
  case published
}

@Attribute(storageMethod: .raw)
var status: Status? = .draft
```

Use this when:

- the stored Core Data field is primitive
- the Swift API should be an enum or another raw-backed type

### Requirements

- the Swift type must conform to `RawRepresentable`
- `.raw` is not inferred automatically
- you must declare it explicitly

### Current boundary

`.raw` is the exception among custom storage methods.

Unlike `.codable`, `.transformed(...)`, and `.composition`, `.raw` may still be used with
non-optional properties, as long as the type is `RawRepresentable` and the property still follows
the normal non-optional default-value rule.

## `.codable`

`.codable` stores the property through `Codable` encoding and decoding.

Example:

```swift
struct ItemConfig: Codable, Equatable {
  var retryCount: Int = 0
}

@Attribute(storageMethod: .codable)
var config: ItemConfig? = nil
```

Use this when:

- the value is a single logical object
- `Data` storage is acceptable
- you want explicit serialization semantics in source code

### Requirements

- the type must conform to `Codable`
- `.codable` is not inferred automatically
- the property must currently be optional
- the only supported explicit default is `nil`

### Why explicit `.codable` matters

This makes the storage choice visible in source.

You do not have to guess whether the framework is:

- storing a payload blob
- flattening members
- or doing something more implicit

## `.transformed(...)`

`.transformed(...)` is for real Core Data `Transformable` storage.

Example:

```swift
@Attribute(storageMethod: .transformed(name: "ColorTransformer"))
var color: NSColor? = nil
```

Use this when:

- you already rely on a `ValueTransformer`
- the storage format is already defined elsewhere
- you need compatibility with an existing Core Data model

### Requirements

- the property must currently be optional
- the only supported explicit default is `nil`
- decode failure behavior can be customized with `decodeFailurePolicy`
- the transformer must be registered before the property is first accessed

Two source forms are currently supported:

- `.transformed(MyTransformer.self)`
- `.transformed(name: "MyTransformerName")`

Use `.transformed(MyTransformer.self)` when:

- you own the transformer type
- it conforms to `CDRegisteredValueTransformer`
- it exposes the same registration name used by the Core Data model

Use `.transformed(name: "...")` when:

- you want the declaration to match the Core Data model directly
- the transformer is already identified by registration name
- you are using source generated by `cde-tool`

### Schema-backed model requirement

For schema-backed Core Data models, `.transformed(...)` only applies when the field itself is
modeled as `Transformable`.

This is the core rule:

- the Swift-facing type is your property type
- the Core Data field type must be `Transformable`
- the Core Data model owns the `valueTransformerName`

Generated accessors use ordinary Core Data KVC reads and writes and let Core Data perform the
object/payload conversion.

The same declaration can also be written in the model-aligned form:

```swift
@Attribute(storageMethod: .transformed(name: "NSSecureUnarchiveFromData"))
var tags: [String]? = nil
```

### Existing-model compatibility

This path is especially useful for existing schemas that already use Core Data `Transformable`
attributes through a stable transformer contract.

For collection payloads such as:

- `[Int]`
- `[String]`
- `[String: String]`

do not treat them as plain primitive storage.

If the model already uses the system secure-unarchive transformer, keep that setup explicit:

- the Core Data model should use the system `NSSecureUnarchiveFromData` transformer (or an
  equivalent custom transformer)
- the Swift declaration should mirror that choice with `.transformed(...)`

Example:

```swift
@Attribute(storageMethod: .transformed(name: "NSSecureUnarchiveFromData"))
var numbers: [Int]? = nil
```

In that case, the schema-backed field should be modeled as `Transformable`.

Because the system transformer is already registered by Foundation, `name:` is the more direct and
model-aligned form here.

Register custom transformers before the model first needs them. Recommended registration points
include:

- app launch
- test bootstrap
- fixture setup
- any earlier static initialization path

If you need tighter control over allowed classes or a pre-existing transformer name, prefer a
dedicated transformer subclass instead of relying on implicit transformable behavior.

## `.composition`

`.composition` is for structured value types that should participate in the macro-generated path
system as a single logical property.

In CoreDataEvolution, `composition` is the source-level term. It corresponds to Core Data's
`composite attribute` concept at the model layer.

Like the other custom storage methods that encode or transform payloads, `.composition` must
currently be declared as optional and may only use `nil` as an explicit default.

Example:

```swift
@Composition
struct GeoPoint {
  var latitude: Double = 0
  var longitude: Double = 0
}

@Attribute(storageMethod: .composition)
var location: GeoPoint? = nil
```

This is the most opinionated storage method in the current design.

It exists because it solves two problems at the same time:

- avoids repeated manual bridging code
- keeps composition leaf paths available for typed mapping

That means you can still write:

```swift
Item.path.location.latitude
```

instead of giving up path-based sort/filter support.

### The Core Data concept behind it

This storage method is the CoreDataEvolution-facing representation of Core Data's composite
attribute model introduced in the WWDC 2023 era.

Conceptually, a composite attribute sits between three older approaches:

- flattening several primitive attributes by hand
- creating a separate entity and relationship
- storing the value as one transformable payload

The Core Data composite approach is attractive because it keeps subfields queryable while still
letting the model describe them as one logical grouped value.

For a good overview of Core Data's composite attributes, see:

- [WWDC 2023, What’s New in Core Data - Composite attributes](https://fatbobman.com/en/posts/what-s-new-in-core-data-in-wwdc23/#composite-attributes)

Important Core Data facts:

- composite attributes are a model-level Core Data feature
- SQLite stores them in an expanded field layout, not as one opaque blob
- subfields can participate in predicates and sorts
- Xcode models them as a composite type, but Core Data does not generate a custom Swift value type
  for you automatically

That last point is exactly where CoreDataEvolution adds value:

- Core Data gives you the storage model
- `@Composition` gives you the Swift value type
- `@Attribute(storageMethod: .composition)` connects the two
- typed paths keep subfield sort/predicate usage available in source

### How CoreDataEvolution models it

In this package, `.composition` is intentionally explicit.

You do not rely on hidden framework synthesis. Instead you declare:

- the Swift struct with `@Composition`
- the property with `storageMethod: .composition`

and the macros generate:

- encode/decode helpers
- field table metadata
- typed subpaths such as `Item.path.location.latitude`

This keeps the storage strategy visible in source and makes later maintenance easier.

### Requirements

The type must be a `@Composition` struct.

Current composition rules:

- only `struct`
- no generics
- only stored `var` properties
- only primitive field types
- no nested composition
- no `.raw`, `.codable`, or `.transformed` inside composition fields
- field renaming is supported through `@CompositionField(persistentName: ...)`

### Schema-backed model setup

If the property is backed by a real `.xcdatamodeld`, the entity must use a real Core Data
composite attribute.

In practice, the model should contain:

- a top-level attribute such as `location`
- `attributeType = Composite`
- a referenced composite type such as `GeoPoint`
- the composite's leaf attributes, such as `latitude` and `longitude`

In Xcode's model editor, that means:

- create one entity attribute whose type is `Composite`
- point that attribute at a named composite type
- declare the leaf fields inside that composite type

Do not model schema-backed `.composition` as `Transformable`. A transformable dictionary payload is
only used by the runtime-only test/debug model builder, not by the real `.xcdatamodeld` workflow.

Also do not flatten those leaf fields directly onto the entity while keeping the Swift source as a
single composition property. A declaration such as `var location: GeoPoint?` expects the Core Data
model to expose a top-level `location` composite attribute.

## Decode Failure Policy

`decodeFailurePolicy` applies to storage methods that actually decode or transform values:

- `.raw`
- `.codable`
- `.transformed(...)`

Supported policies:

- `.fallbackToDefaultValue`
- `.debugAssertNil`

Example:

```swift
@Attribute(
  storageMethod: .codable,
  decodeFailurePolicy: .fallbackToDefaultValue
)
var config: ItemConfig? = nil
```

For `.codable` and `.transformed(...)`, `.fallbackToDefaultValue` currently falls back to `nil`.
Those storage methods are limited to optional declarations and do not support non-`nil` source
defaults, so there is no separate model-backed value to reconstruct after a decode failure.

This policy does not apply to plain primitive `.default` storage.

## `transient` Is Not a Storage Method

`transient` is a trait, not a storage method:

```swift
@Attribute(.transient)
var cachedSummary: String = ""
```

It still matters here because it changes how the attribute participates in the Core Data model.

Current rule:

- `transient` only supports `.default`

So these are rejected:

```swift
@Attribute(.transient, storageMethod: .raw)
var state: Status? = nil

@Attribute(.transient, storageMethod: .composition)
var location: GeoPoint? = nil
```

## How to Choose a Storage Method

Use this rough decision tree:

- If the type is already a supported primitive -> `.default`
- If the type is `RawRepresentable` -> `.raw`
- If the type is a logical payload object and `Data` storage is acceptable -> `.codable`
- If an existing model already uses `Transformable` or a custom transformer -> `.transformed(...)`
- If the type is a structured value you want to expose through typed subpaths -> `.composition`

## Why This Works Better Than Hand-Written Bridging

With explicit `storageMethod`, you keep:

- one declaration of intent
- one generated conversion pattern
- one validation surface
- one key/path mapping layer

Instead of hand-writing:

- raw backing field
- computed property bridge
- sort/predicate string exceptions
- decode fallback behavior

over and over again.

## Relationship to Other Guides

- See [PersistentModelGuide.md](./PersistentModelGuide.md) for the full macro overview.
- See [TypedPathGuide.md](./TypedPathGuide.md) for the key/path mapping layer used by sort and
  predicate construction.

`storageMethod` and typed path mapping are closely related:

- storage controls how the value is persisted
- typed path mapping controls how the persisted field path is exposed safely in code

Together, they let you keep a better Swift-facing model API without giving up store-backed sort and
predicate support.
