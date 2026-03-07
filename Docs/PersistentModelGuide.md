# PersistentModel Guide

`@PersistentModel` brings a Swift-first declaration style to Core Data models while keeping the
runtime on top of `NSManagedObject`.

This guide is written for library users. It focuses on:

- the supported declaration style
- generated APIs and metadata
- required modeling rules
- common mistakes and the diagnostics you should expect

The current design is intentionally strict. The goal is predictable code generation, stable macro
expansion, and tooling-friendly validation.

## Overview

A `@PersistentModel` type is still an `NSManagedObject` subclass. You declare stored properties in
Swift, and the macros generate the boilerplate needed for:

- Core Data key-value accessors
- typed `Keys` and `path`
- field metadata for sort and predicate building
- runtime schema metadata for test/debug-only model construction
- optional relationship helper methods

The macro system works together with these supporting macros:

- `@Attribute`
- `@Ignore`
- `@Composition`
- `@Relationship`

## Minimal Example

```swift
import CoreData
import CoreDataEvolution

@objc(Item)
@PersistentModel
final class Item: NSManagedObject {
  var title: String = ""
  var timestamp: Date? = nil
}
```

Requirements shown in this example:

- The type must be a `class`.
- The type must inherit from `NSManagedObject`.
- The type must declare `@objc(EntityName)` explicitly.
- Every persisted property must be optional, or provide a default value.

## What `@PersistentModel` Generates

For a valid model type, the macro generates:

- `Keys`
- `Paths`
- `path`
- `__cdFieldTable`
- `__cdRelationshipProjectionTable`
- `__cdRuntimeEntitySchema`
- optional convenience `init(...)` when `generateInit: true`
- to-many add/remove helpers
- `PersistentEntity` conformance
- `CDRuntimeSchemaProviding` conformance

You should treat these generated members as implementation details. Write your model declarations in
source, and let the macro own the generated layer.

## Declaring Attributes

Plain stored properties default to persisted attributes:

```swift
@objc(Item)
@PersistentModel
final class Item: NSManagedObject {
  var title: String = ""
  var notes: String? = nil
  var createdAt: Date = .distantPast
}
```

Use `@Attribute` when you need more control.

### Rename a Persistent Field

```swift
@Attribute(persistentName: "name")
var title: String = ""
```

This means:

- Swift property name: `title`
- Core Data persistent field name: `name`

This is intentionally different from SwiftData's `originalName`.

- In SwiftData, `originalName` is a migration hint. It means "this property used to be named
  something else in an older schema version."
- In CoreDataEvolution, `persistentName` is a storage mapping. It means "this Swift property is
  backed by this Core Data field name right now."

Example:

```swift
// SwiftData-style migration meaning
@Attribute(originalName: "name")
var title: String

// CoreDataEvolution storage mapping meaning
@Attribute(persistentName: "name")
var title: String = ""
```

This renamed mapping also feeds the library's typed path system automatically. You still write
Swift-facing property names in code, while sort and predicate construction resolve them to the
correct Core Data field name internally.

Example:

```swift
let sort = try NSSortDescriptor(
  Item.self,
  path: Item.path.title,
  order: .asc
)

let predicate = NSPredicate(
  format: "%K == %@",
  Item.path.title.raw,
  "hello"
)
```

With `@Attribute(persistentName: "name") var title: String = ""`, the generated path still uses
`title` in Swift code, but maps it to the persistent field `name` when building `%K`-based
predicates or sort descriptors.

For a dedicated guide to this mapping layer, including the motivation, `NSSortDescriptor`,
`NSPredicate`, and to-many quantifier examples, see [TypedPathGuide.md](./TypedPathGuide.md).

### Unique Constraint

```swift
@Attribute(.unique)
var slug: String = ""
```

In v1, `.unique` is a simple trait. It represents a single-field uniqueness constraint.

### Transient Attribute

```swift
@Attribute(.transient)
var cachedSummary: String = ""
```

`transient` means:

- the property belongs to the Core Data model
- the value is not persisted to the store
- it is different from `@Ignore`

V1 restrictions for `transient`:

- only supported with `.default` storage
- cannot be combined with `.unique`
- cannot be combined with `.raw`, `.codable`, `.transformed`, or `.composition`

### Raw-Representable Storage

```swift
enum Status: String {
  case draft
  case published
}

@Attribute(storageMethod: .raw)
var status: Status? = .draft
```

Use `.raw` for enums or other `RawRepresentable` types.

### Codable Storage

```swift
struct ItemConfig: Codable, Equatable {
  var retryCount: Int = 0
}

@Attribute(storageMethod: .codable)
var config: ItemConfig? = nil
```

### Value Transformer Storage

```swift
@Attribute(storageMethod: .transformed(CDEStringListTransformer.self))
var keywords: [String]? = nil
```

### Decode Failure Policy

Decode failure policies only make sense for storage methods that actually decode values.

```swift
@Attribute(
  storageMethod: .codable,
  decodeFailurePolicy: .fallbackToDefaultValue
)
var config: ItemConfig? = nil
```

Supported policies:

- `.fallbackToDefaultValue`
- `.debugAssertNil`

For a dedicated guide to storage choices, tradeoffs, and v1 limits of `.default`, `.raw`,
`.codable`, `.transformed`, and `.composition`, see
[StorageMethodGuide.md](./StorageMethodGuide.md).

## Declaring Relationships

There is no separate public relationship macro in v1.

Relationships are inferred from the property type:

```swift
@objc(Item)
@PersistentModel
final class Item: NSManagedObject {
  var tag: Tag?
  var tags: Set<Tag>
  var orderedTags: [Tag]
}
```

Interpretation:

- `Tag?` -> to-one relationship
- `Set<Tag>` -> unordered to-many relationship
- `[Tag]` -> ordered to-many relationship

### Required Relationship Rules

#### To-one relationships must be optional

Valid:

```swift
var category: Category?
```

Invalid:

```swift
var category: Category
```

Why:

- v1 requires relationship declarations to follow a predictable optional/default model
- non-optional to-one relationships are rejected at macro validation time

#### To-many relationships must not be optional

Valid:

```swift
var tags: Set<Tag>
var orderedTags: [Tag]
```

Invalid:

```swift
var tags: Set<Tag>?
var orderedTags: [Tag]?
```

Why:

- the model may mark the relationship optional internally
- but Swift declarations must use the collection type directly
- use `Set<T>` or `[T]`, not `Set<T>?` or `[T]?`

#### Every relationship must have an inverse in the model

Core Data models using this library must define inverse relationships.

If the inverse is missing, tooling and validation reject the model.

#### Every relationship must declare `@Relationship(...)`

Relationship cardinality is still inferred from the Swift property type, but relationship metadata
is explicit in source.

Example:

```swift
@objc(Item)
@PersistentModel
final class Item: NSManagedObject {
  @Relationship(inverse: "items", deleteRule: .nullify)
  var tag: Tag?
}

@objc(Tag)
@PersistentModel
final class Tag: NSManagedObject {
  @Relationship(inverse: "tag", deleteRule: .nullify)
  var items: Set<Item>
}
```

`@Relationship(...)` always carries:

- `inverse`
- `deleteRule`

It can also carry optional count bounds when the Core Data model declares them:

- `minimumModelCount`
- `maximumModelCount`

Example:

```swift
@Relationship(
  inverse: "documents",
  deleteRule: .deny,
  minimumModelCount: 1,
  maximumModelCount: 3
)
var owner: Owner?
```

You do not need to write these count arguments when the model uses Core Data's default bounds for
that relationship shape:

- optional to-one: `0...1`
- non-optional to-one: `1...1`
- to-many: `0...0` unless the model explicitly constrains it

Write them only when the model declares non-default minimum or maximum counts.

There is no source-level inverse inference in the current model DSL.

Supported delete rules in v1:

- `.nullify`
- `.cascade`
- `.deny`

`.noAction` is intentionally unsupported.

### Multiple Relationships to the Same Target Entity

Example:

```swift
@objc(Document)
@PersistentModel
final class Document: NSManagedObject {
  @Relationship(inverse: "authoredDocuments", deleteRule: .nullify)
  var author: User?

  @Relationship(inverse: "editedDocuments", deleteRule: .nullify)
  var editor: User?
}

@objc(User)
@PersistentModel
final class User: NSManagedObject {
  @Relationship(inverse: "author", deleteRule: .nullify)
  var authoredDocuments: Set<Document>

  @Relationship(inverse: "editor", deleteRule: .nullify)
  var editedDocuments: Set<Document>
}
```

This works the same way for self-referencing models.

### Self-Referencing Relationship Example

```swift
@objc(Category)
@PersistentModel
final class Category: NSManagedObject {
  @Relationship(inverse: "children", deleteRule: .nullify)
  var parent: Category?

  @Relationship(inverse: "parent", deleteRule: .nullify)
  var children: Set<Category>
}
```

## Declaring Compositions

Use `@Composition` for value-like grouped data that should still participate in typed paths and
model metadata.

In CoreDataEvolution, the source-level term is `composition`. It corresponds to Core Data's
`composite attribute` feature at the model layer.

```swift
@Composition
struct Location {
  var x: Double = 0
  var y: Double? = nil
}

@objc(Item)
@PersistentModel
final class Item: NSManagedObject {
  @Attribute(storageMethod: .composition)
  var location: Location? = nil
}
```

### Composition Rules in V1

A composition type must be:

- a `struct`
- non-generic
- made of stored `var` properties only
- limited to supported primitive field types and optionals
- non-nested
- free of rename/conversion behavior in v1

`@Composition` generates metadata used by:

- typed paths
- encode/decode helpers
- runtime schema metadata for test/debug model construction

## Ignored Properties

Use `@Ignore` for pure Swift properties that should not participate in the Core Data model.

```swift
@Ignore
var transientCache: [String: Int] = [:]
```

`@Ignore` means:

- not persisted
- not part of the generated Core Data schema
- not part of typed path metadata
- still included in generated init when `generateInit: true`

Use `@Ignore` for in-memory state. Use `@Attribute(.transient)` for Core Data transient
attributes.

## Default Value Rules

V1 keeps default-value semantics strict.

### Persisted Properties

A persisted property must be one of:

- optional
- non-optional with an explicit default value

Valid:

```swift
var title: String = ""
var notes: String? = nil
var createdAt: Date = .distantPast
```

Invalid:

```swift
var title: String
```

The declared Swift default value should match the default configured in your Core Data model.

For example, if the model defines `title` with a default of `""`, your Swift declaration should
also use:

```swift
var title: String = ""
```

Do not treat the Swift default as a way to override the model's default value.

In v1, the declared default value is used for these purposes:

- to make the declaration explicit and toolable
- to satisfy the "optional or default" model rule
- as a fallback when custom decoding fails, depending on storage method and decode failure policy

It is not used to rewrite or replace the default value stored in the `.xcdatamodeld`.

### Why This Rule Exists

The rule keeps several parts of the system consistent:

- macro-generated accessors
- tooling generate/validate
- runtime schema generation for tests and debugging

### Optional Properties

Optional properties may explicitly write `= nil`, but they do not have to.

Both are accepted:

```swift
var notes: String?
var notes: String? = nil
```

### Custom Storage and Non-Optional Values

In v1, non-optional custom storage declarations are intentionally restricted.

Do not rely on code-side conversion defaults for:

- `.raw`
- `.codable`
- `.transformed`
- `.composition`

If you need one of these storage methods, prefer an optional property in v1.

## Generated Init

`@PersistentModel` does not generate an init by default.

```swift
@PersistentModel(generateInit: true)
```

When enabled, the generated init:

- includes persisted attributes
- includes `@Ignore` properties
- excludes relationships
- does not inject a Core Data context parameter

Example:

```swift
@objc(Item)
@PersistentModel(generateInit: true)
final class Item: NSManagedObject {
  var title: String = ""

  @Ignore
  var transientCache: [String: Int] = [:]

  var tags: Set<Tag>
}
```

Generated init shape:

```swift
convenience init(
  title: String,
  transientCache: [String: Int]
)
```

## Runtime Schema for Tests and Debugging

`@PersistentModel` also emits runtime schema metadata.

This supports pure Swift model construction for:

- tests
- debug utilities
- non-Xcode workflows that do not want to depend on `.xcdatamodeld`

This runtime schema path is intentionally limited:

- it is test/debug-only
- it is not a replacement for production `.xcdatamodeld`
- it does not guarantee model hash or migration compatibility

Example:

```swift
let model = try NSManagedObjectModel.makeRuntimeModel(Item.self, Tag.self)

let container = try NSPersistentContainer.makeRuntimeTest(
  modelTypes: Item.self, Tag.self
)
```

`makeRuntimeModel` and `makeRuntimeTest` intentionally use slightly different call shapes, but both
consume the same runtime schema provider types.

## PersistentModel Rules Checklist

Before using `@PersistentModel`, make sure all of these are true.

### Type-Level Rules

- must be a `class`
- must inherit from `NSManagedObject`
- must declare `@objc(EntityName)` explicitly
- must not declare multiple stored properties in a single `var` declaration

### Attribute Rules

- every persisted attribute must be optional or have a default value
- `.unique` is supported
- `.transient` is supported only with `.default`
- derived attributes are not supported
- renamed attributes use `persistentName:`

### Relationship Rules

- to-one relationships must be optional
- to-many relationships must use `Set<T>` or `[T]`
- to-many relationships cannot be optional
- relationships must have inverses in the Core Data model
- every relationship must declare `@Relationship(inverse:deleteRule:)`
- relationship count bounds are optional source metadata and should only be written when the model
  declares non-default min/max values
- supported relationship delete rules are `.nullify`, `.cascade`, and `.deny`
- `.noAction` is not supported

### Composition Rules

- composition type must use `@Composition`
- composition type must be a non-generic `struct`
- composition fields must be supported primitive fields
- nested composition is not supported in v1

## Invalid Examples

### Multiple Stored Properties in One Declaration

Invalid:

```swift
var title: String = "", subtitle: String = ""
```

Reason:

- `@PersistentModel` does not support multi-binding stored declarations
- split them into separate `var` declarations

Correct:

```swift
var title: String = ""
var subtitle: String = ""
```

### Non-Optional To-One Relationship

Invalid:

```swift
var category: Category
```

Correct:

```swift
var category: Category?
```

### Optional To-Many Relationship

Invalid:

```swift
var tags: Set<Tag>?
```

Correct:

```swift
var tags: Set<Tag>
```

### Missing `@Relationship` Metadata

Invalid:

```swift
var tag: Tag?
```

Correct:

```swift
@Relationship(inverse: "items", deleteRule: .nullify)
var tag: Tag?
```

### Unsupported `No Action` Delete Rule

Invalid:

```swift
@Relationship(inverse: "items", deleteRule: .noAction)
var tag: Tag?
```

Correct:

```swift
@Relationship(inverse: "items", deleteRule: .nullify)
var tag: Tag?
```

### Transient with Unsupported Storage

Invalid:

```swift
@Attribute(.transient, storageMethod: .raw)
var cachedSummary: String = ""
```

Correct:

```swift
@Attribute(.transient)
var cachedSummary: String = ""
```

### Unsupported Derived Attribute

Derived Attribute is currently out of scope.

If your Core Data model uses derived attributes, the current toolchain rejects that model.

## Common Diagnostics

Examples of expected diagnostics:

- `@PersistentModel can only be attached to a class declaration.`
- `@PersistentModel type must inherit from NSManagedObject.`
- `@PersistentModel type must declare @objc(ClassName) explicitly.`
- `@PersistentModel does not support declaring multiple stored properties in one var declaration.`
- `To-one relationship properties must be optional.`
- `Optional to-many relationship ... is not supported.`
- `Relationship property 'tag' must declare @Relationship(inverse: ..., deleteRule: ...).`
- `@Relationship does not support deleteRule: .noAction in v1.`
- `@Attribute trait .transient only supports .default storage.`
- `Derived Attribute is not supported.`

## Recommended Style

A good v1 style looks like this:

```swift
import CoreData
import CoreDataEvolution

@Composition
struct Location {
  var x: Double = 0
  var y: Double? = nil
}

enum ItemStatus: String {
  case draft
  case published
}

@objc(Item)
@PersistentModel(generateInit: true, relationshipSetterPolicy: .warning)
final class Item: NSManagedObject {
  @Attribute(.unique)
  var slug: String = ""

  @Attribute(persistentName: "name")
  var title: String = ""

  @Attribute(storageMethod: .raw)
  var status: ItemStatus? = .draft

  @Attribute(storageMethod: .composition)
  var location: Location? = nil

  @Attribute(.transient)
  var cachedSummary: String = ""

  @Ignore
  var uiState: [String: Int] = [:]

  @Relationship(inverse: "items", deleteRule: .nullify)
  var tag: Tag?
}

@objc(Tag)
@PersistentModel
final class Tag: NSManagedObject {
  var name: String = ""
  @Relationship(inverse: "tag", deleteRule: .nullify)
  var items: Set<Item>
}
```

This style matches the current macro, tooling, and runtime-schema expectations closely.

## V1 Boundaries

`@PersistentModel` v1 is intentionally conservative.

Not supported yet:

- Derived Attribute
- nested composition
- entity inheritance
- production-oriented runtime model replacement for `.xcdatamodeld`
- optional to-many declarations
- non-optional to-one declarations

When in doubt, prefer the simplest declaration shape that matches the rules in this guide.
