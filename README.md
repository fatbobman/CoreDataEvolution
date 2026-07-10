# CoreDataEvolution

CoreDataEvolution brings actor isolation, Swift-first `NSManagedObject` declarations, typed paths, runtime schema metadata, and model tooling to Core Data.

![Swift](https://img.shields.io/badge/Swift-6.0%2B-orange?style=flat) ![Platforms](https://img.shields.io/badge/Platforms-iOS%2013%2B%20%7C%20macOS%2010.15%2B%20%7C%20tvOS%2013%2B%20%7C%20watchOS%206%2B%20%7C%20visionOS%201%2B-blue?style=flat) ![License](https://img.shields.io/badge/License-MIT-green?style=flat) [![DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/fatbobman/CoreDataEvolution)

English | [中文](README_zh.md)

## Motivation

Core Data remains a pragmatic foundation for apps that depend on its mature object graph, migration, and store behavior, but its default source and concurrency patterns can feel distant from modern Swift. Projects often accumulate hand-written accessors, string-based query keys, context-passing conventions, and schema-to-source drift.

CoreDataEvolution keeps Core Data as the persistence engine while making its Swift surface more explicit and toolable. It combines actor-isolated access, macro-based `NSManagedObject` declarations, typed mapping, optional Observation support, and a CLI that can compare source declarations with the real model.

Related reading: [Why I'm Still Thinking About Core Data in 2026](https://fatbobman.com/en/posts/why-i-am-still-thinking-about-core-data-in-2026/)

## Features

- Isolate background work with `@NSModelActor`, or bind UI-facing orchestration to `viewContext` with `@NSMainModelActor`.
- Declare Core Data entities in Swift with `@PersistentModel`, plus explicit attribute, relationship, composition, and storage metadata.
- Generate typed keys and paths for sort descriptors and `%K`-based predicates, including renamed fields and relationship paths.
- Opt generated accessors into MainActor Observation on supported Swift and OS versions.
- Build runtime schemas and isolated SQLite containers for test and debug workflows without replacing production `.xcdatamodeld` files.
- Use `cde-tool` to generate declarations, validate model/source alignment, inspect models, and bootstrap configuration.

## Quick Start

Add CoreDataEvolution to your package with Swift Package Manager:

```swift
dependencies: [
  .package(
    url: "https://github.com/fatbobman/CoreDataEvolution.git",
    from: "0.9.3"
  )
],
targets: [
  .target(
    name: "YourTarget",
    dependencies: [
      .product(name: "CoreDataEvolution", package: "CoreDataEvolution")
    ]
  )
]
```

The following executable example declares one entity, creates a test/debug runtime model, and saves through a MainActor-isolated `viewContext`:

```swift
import CoreDataEvolution
import Foundation

@objc(Item)
@PersistentModel
final class Item: NSManagedObject {
  var title: String = ""
}

@MainActor
@NSMainModelActor
final class ItemStore {
  func createItem(title: String) throws {
    let item = Item(context: modelContext)
    item.title = title
    try modelContext.save()
  }
}

@main
struct Example {
  @MainActor
  static func main() throws {
    let container = try NSPersistentContainer.makeRuntimeTest(modelTypes: Item.self)
    let store = ItemStore(modelContainer: container)
    try store.createItem(title: "Hello, Core Data")
  }
}
```

`makeRuntimeTest` is intentionally limited to tests and debugging. Production apps should keep a matching Core Data model and pass their loaded `NSPersistentContainer` to an `@NSModelActor` or `@NSMainModelActor` type.

## Where to Read Next

- Want actor-isolated Core Data access? Read the [NSModelActor Guide](Docs/NSModelActorGuide.md).
- Want Swift-first model declarations and generated members? Read the [PersistentModel Guide](Docs/PersistentModelGuide.md).
- Want SwiftUI to observe generated Core Data accessors? Read the [Observation Guide](Docs/ObservationGuide.md).
- Want type-safe sort and predicate paths? Read the [TypedPath Guide](Docs/TypedPathGuide.md).
- Want to choose attribute storage strategies? Read the [Storage Method Guide](Docs/StorageMethodGuide.md).
- Want to generate or validate declarations with the CLI? Read the [cde-tool Guide](Docs/CDEToolGuide.md).
- Want to understand the CLI's current boundaries? Read [cde-tool Known Limitations](Docs/CDEToolKnownLimitations.md).

## Requirements

- MainActor Observation requires a Swift 6.2+ compiler and iOS 17+, macOS 14+, tvOS 17+, watchOS 10+, or visionOS 1+.
- Core Data composite attributes require iOS 17+, macOS 14+, tvOS 17+, watchOS 10+, or visionOS 1+.

## Contributing & Testing

Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening an issue or pull request. Start local validation with `swift build` and `bash Scripts/run-tests.sh`; report security-sensitive issues through [SECURITY.md](SECURITY.md).

## License

CoreDataEvolution is available under the MIT license. See the [LICENSE](LICENSE) file for more information.

## Author

**Fatbobman (肘子)** — Blog: [fatbobman.com](https://fatbobman.com) · X: [@fatbobman](https://x.com/fatbobman)

## Support

If this project helps you, please consider supporting my work:

- 📮 Subscribe to [Fatbobman's Swift Weekly](https://weekly.fatbobman.com) — fresh Swift and Apple-ecosystem insights every week
- ☕️ [Buy Me a Coffee](https://buymeacoffee.com/fatbobman)
