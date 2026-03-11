# CoreDataEvolution

![Swift 6](https://img.shields.io/badge/Swift-6-orange?logo=swift) ![iOS](https://img.shields.io/badge/iOS-13.0+-green) ![macOS](https://img.shields.io/badge/macOS-10.15+-green) ![watchOS](https://img.shields.io/badge/watchOS-6.0+-green) ![visionOS](https://img.shields.io/badge/visionOS-1.0+-green) ![tvOS](https://img.shields.io/badge/tvOS-13.0+-green) [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE) [![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/fatbobman/CoreDataEvolution)

CoreDataEvolution **does not** replace Core Data. It modernizes how Core Data is expressed, isolated, and maintained in Swift codebases.

CoreDataEvolution brings three ideas together for Core Data projects:

- SwiftData-style actor isolation for Core Data
- a Swift-first source representation for `NSManagedObject` models
- tooling that keeps source declarations aligned with the real Core Data model

This document focuses on the user-facing story:

- what the library is for
- which pain points it solves
- what the major features are
- how the pieces fit together
- where to go next in the detailed guides

## What Problem This Library Solves

Core Data remains the practical choice for many production apps because it offers:

- broad platform support
- mature migration and store behavior
- existing schemas that teams cannot easily replace

But Core Data still has several recurring pain points in modern Swift codebases.

### Pain Point 1: Concurrency ergonomics

SwiftData introduced a much better concurrency story through `@ModelActor`.

Traditional Core Data code often falls back to:

- manually passing contexts around
- remembering thread confinement rules
- reloading objects by `NSManagedObjectID`
- building ad hoc background helpers

CoreDataEvolution brings that actor-isolated workflow to Core Data.

### Pain Point 2: The `NSManagedObject` source layer is awkward

The classic Core Data source representation works, but it does not scale well when you want:

- better Swift-facing names than the stored schema names
- enums instead of raw values
- Codable payloads
- transformable values
- structured composition values
- predictable generated boilerplate instead of repeated hand-written bridging

CoreDataEvolution adds a source-layer model DSL around `NSManagedObject` while keeping the real Core Data runtime underneath.

### Pain Point 3: Schema drift is easy

Once a Core Data model ships, schema names often become hard to change safely.

That creates pressure to keep old store names while still wanting better Swift-facing names.

Without tooling, teams end up with:

- hand-written mapping code
- stringly-typed sort and predicate keys
- drift between `.xcdatamodeld` and source declarations

CoreDataEvolution includes `cde-tool` to generate, validate, inspect, and safely autofix parts of that source layer.

## Mental Model

The project is built around one central idea:

> `@PersistentModel` is a source-level representation of a Core Data model, not a replacement for Core Data itself.

That distinction matters.

### What `@PersistentModel` is

It is a Swift-facing declaration layer for:

- attributes
- relationships
- composition values
- generated typed path metadata
- generated runtime schema metadata for test/debug use

### What `@PersistentModel` is not

It is not:

- a replacement for `.xcdatamodeld` in production
- a migration system
- a different persistence engine
- a runtime reflection layer

The production source of truth is still your Core Data model.

The macro layer gives you a better, more explicit, more toolable representation of that model in Swift source.

This is the most important mental model for new users:

- keep building the real schema in Xcode
- use `@PersistentModel` to describe that schema in Swift
- use `cde-tool` to keep the two layers aligned

## The Three Main Parts of the Package

### 1. Actor isolation for Core Data

Use:

- `@NSModelActor`
- `@NSMainModelActor`

These macros generate the boilerplate needed to safely work with Core Data through actor isolation or main-actor isolation.

Good fit:

- background write handlers
- UI-facing main-thread coordinators
- tests that need explicit isolation boundaries

Guide:

- [Docs/NSModelActorGuide.md](./Docs/NSModelActorGuide.md)

### 2. `@PersistentModel` and related macros

Use:

- `@PersistentModel`
- `@Attribute`
- `@Relationship`
- `@Ignore`
- `@Composition`
- `@CompositionField`

This is the model declaration layer.

It gives you:

- explicit attribute/relationship metadata
- generated Core Data accessors
- generated to-many relationship helper APIs
- typed key/path metadata for sort and predicate construction
- runtime schema metadata for tests and debug workflows

Guide:

- [Docs/PersistentModelGuide.md](./Docs/PersistentModelGuide.md)

### 3. `cde-tool`

Use `cde-tool` when you want a repeatable model-to-source workflow.

It is intentionally optional.

The core value of CoreDataEvolution lives in the actor-isolation macros and the macro-based model
declaration layer. You can use those directly without adopting the tool at all.

`cde-tool` exists as an extra layer for teams that want stronger workflow guarantees, especially
for CI/CD, drift detection, and existing-project migration.

It helps with:

- generating `@PersistentModel` source from an existing Core Data model
- validating drift between `.xcdatamodeld` and source declarations
- inspecting the resolved schema view used by the toolchain
- applying safe autofix for deterministic issues

That first point is especially useful when adopting the package in an existing Core Data project:
the tool can quickly turn a legacy `.xcdatamodeld` into a usable `@PersistentModel` starting point,
similar in spirit to Xcode's model code generation, but aligned with CoreDataEvolution's macro
layer.

Guide:

- [Docs/CDEToolGuide.md](./Docs/CDEToolGuide.md)

## Core Features

### SwiftData-style actor isolation for Core Data

```swift
import CoreDataEvolution

@NSModelActor
actor ItemStore {
  func renameItem(id: NSManagedObjectID, to newTitle: String) throws {
    guard let item = self[id, as: Item.self] else { return }
    item.title = newTitle
    try modelContext.save()
  }
}
```

This lets you keep Core Data while moving to a much cleaner isolation model.

### Swift-first model declarations on top of `NSManagedObject`

```swift
@objc(Item)
@PersistentModel
final class Item: NSManagedObject {
  @Attribute(persistentName: "name")
  var title: String = ""

  @Relationship(inverse: "items", deleteRule: .nullify)
  var tag: Tag?
}
```

This is the most important thing to understand:

- the source is Swift-first
- the runtime is still Core Data
- the model file is still part of the system

For relationships:

- to-one properties generate a getter and setter
- to-many properties (`Set<T>` / `[T]`) generate a getter only
- mutate to-many relationships through generated helpers such as `addToTags`,
  `removeFromTags`, and `insertIntoOrderedTags(_:at:)`

### Typed key/path mapping for sort and predicate code

This is one of the library's distinctive features.

When a Swift-facing property name differs from the stored schema name, the macro-generated typed path layer still resolves sort and predicate keys to the correct persistent field path.

That means you can write:

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

while the store still uses the original field name.

Guide:

- [Docs/TypedPathGuide.md](./Docs/TypedPathGuide.md)

### Explicit storage strategy selection

The source layer makes storage strategy explicit instead of burying it in hand-written bridging code.

Supported source-level storage choices include:

- `.default`
- `.raw`
- `.codable`
- `.transformed(...)`
- `.composition`

Guide:

- [Docs/StorageMethodGuide.md](./Docs/StorageMethodGuide.md)

## Important Preconditions

These are the points that new users most often need clarified.

### `@PersistentModel` works with Core Data models

For production use, `@PersistentModel` is not a replacement for `.xcdatamodeld`.

You still build and maintain a Core Data model.

The macro layer is the source representation that sits on top of it.

That means:

- you still need a Core Data source model for production workflows
- `cde-tool` reads that model and helps generate/validate the Swift declaration layer
- the macro-generated runtime schema is for test/debug scenarios, not for replacing the production model system
- unsupported runtime primitive types fail generation instead of silently downgrading schema

### Relationship `inverse` uses the persistent relationship name

This is easy to miss.

In:

```swift
@Relationship(
  persistentName: "primary_category",
  inverse: "items",
  deleteRule: .nullify
)
var category: Category?
```

`inverse` refers to the relationship name in the Core Data model on the other side.

It does **not** refer to the other Swift property name.

### `composition` requires Core Data composite attribute support

`@Composition` maps to Core Data composite attributes.

For schema-backed models, this means the Xcode model must declare a real top-level `Composite`
attribute, not a pair of flattened entity fields and not a `Transformable` fallback.

That means it requires platform support for that Core Data feature:

- iOS 17+
- macOS 14+
- tvOS 17+
- watchOS 10+
- visionOS 1+

If your deployment target is below those versions, do not use `composition`.

## Runtime Schema for Tests and Debugging

The package also supports a pure Swift runtime-schema path for tests and debugging.

Example:

```swift
let model = try NSManagedObjectModel.makeRuntimeModel(Item.self, Tag.self)

let container = try NSPersistentContainer.makeRuntimeTest(
  modelTypes: Item.self, Tag.self
)
```

This path is intentionally limited.

It is useful when you want:

- test-only model construction
- debug-only schema checks
- non-Xcode workflows for tests

It is not intended to replace `.xcdatamodeld` in production.

## `cde-tool` Workflow

Typical workflow:

1. start from a Core Data source model
2. create a config
3. generate `@PersistentModel` source
4. add hand-written methods and computed properties in separate extension files
5. validate drift over time

Typical first setup:

```bash
cde-tool bootstrap-config \
  --model-path Models/AppModel.xcdatamodeld \
  --output cde-tool.json
```

Then:

```bash
cde-tool generate --config cde-tool.json
cde-tool validate --config cde-tool.json
```

### Validation modes

`cde-tool validate` supports two mental models:

- `conformance`
  - checks whether source follows the rules and matches the schema logically
- `exact`
  - additionally requires tool-managed files to match current generated output exactly

`exact` is intentionally stricter and should not be the default workflow for every team.

If you use `exact`, keep these rules in mind:

- do not hand-edit tool-managed files
- do not let format/lint rewrite tool-managed files
- add custom methods and computed properties in separate extension files

## Recommended Project Structure

A practical structure looks like this:

- Core Data model in `Models/`
- generated source in a dedicated generated folder
- hand-written extensions in separate files
- `cde-tool.json` checked into the repository

Example:

- `Models/AppModel.xcdatamodeld`
- `Sources/AppModels/Generated/`
- `Sources/AppModels/Item+Extras.swift`
- `cde-tool.json`

This keeps generated and hand-written code clearly separated.

## Where to Read Next

Start here based on what you want to do.

### If you want actor-isolated Core Data code

- [Docs/NSModelActorGuide.md](./Docs/NSModelActorGuide.md)

### If you want Swift-first Core Data model declarations

- [Docs/PersistentModelGuide.md](./Docs/PersistentModelGuide.md)

### If you want remapped fields to still work in sort and predicate code

- [Docs/TypedPathGuide.md](./Docs/TypedPathGuide.md)

### If you want to choose the right storage strategy

- [Docs/StorageMethodGuide.md](./Docs/StorageMethodGuide.md)

### If you want the CLI workflow

- [Docs/CDEToolGuide.md](./Docs/CDEToolGuide.md)

## Summary

CoreDataEvolution is not trying to replace Core Data.

It is trying to make Core Data easier to use in modern Swift codebases by adding:

- better isolation patterns
- better model source declarations
- better schema-to-source tooling
- better typed mapping for renamed fields

If your project still relies on Core Data, but you want a source model and workflow that feel much
closer to modern Swift, that is the space this library is designed for.

## System Requirements

- iOS 13.0+ / macOS 10.15+ / watchOS 6.0+ / visionOS 1.0+ / tvOS 13.0+
- Swift 6.0

Note: The custom executor uses a compatible `UnownedJob` serial-executor path to support the minimum deployment targets.

## Contributing

We welcome contributions! Whether you want to report issues, propose new features, or contribute to the code, feel free to open issues or pull requests on the GitHub repository.

## License

CoreDataEvolution is available under the MIT license. See the LICENSE file for more information.

## Acknowledgments

Special thanks to the Swift community for their continuous support and contributions.
Thanks to [@rnine](https://github.com/rnine) for sharing and validating the iOS 13+ compatibility approach that inspired this adaptation.

## Support the project

- [🎉 Subscribe to my Swift Weekly](https://weekly.fatbobman.com)
- [☕️ Buy Me A Coffee](https://buymeacoffee.com/fatbobman)

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=fatbobman/CoreDataEvolution&type=Date)](https://star-history.com/#fatbobman/CoreDataEvolution&Date)
