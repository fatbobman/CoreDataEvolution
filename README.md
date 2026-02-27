# CoreDataEvolution

![Swift 6](https://img.shields.io/badge/Swift-6-orange?logo=swift) ![iOS](https://img.shields.io/badge/iOS-13.0+-green) ![macOS](https://img.shields.io/badge/macOS-10.15+-green) ![watchOS](https://img.shields.io/badge/watchOS-6.0+-green) ![visionOS](https://img.shields.io/badge/visionOS-1.0+-green) ![tvOS](https://img.shields.io/badge/tvOS-13.0+-green) [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE) [![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/fatbobman/CoreDataEvolution)

## Revolutionizing Core Data with SwiftData-inspired Concurrent Operations

Welcome to CoreDataEvolution, a library aimed at modernizing Core Data by incorporating the elegance and safety of SwiftData-style concurrency. This library is designed to simplify and enhance Core Data’s handling of multithreading, drawing inspiration from SwiftData's `@ModelActor` feature, enabling efficient, safe, and scalable operations.

---

Don't miss out on the latest updates and excellent articles about Swift, SwiftUI, Core Data, and SwiftData. Subscribe to **[Fatbobman's Swift Weekly](https://weekly.fatbobman.com)** and receive weekly insights and valuable content directly to your inbox.

---

## Motivation

SwiftData introduced modern concurrency features like `@ModelActor`, making it easier to handle concurrent data access with safety guaranteed by the compiler. However, SwiftData's platform requirements and limited maturity in certain areas have deterred many developers from adopting it. CoreDataEvolution bridges the gap, bringing SwiftData’s advanced design into the Core Data world for developers who are still reliant on Core Data.

* [Core Data Reform: Achieving Elegant Concurrency Operations like SwiftData](https://fatbobman.com/en/posts/core-data-reform-achieving-elegant-concurrency-operations-like-swiftdata/)
* [Practical SwiftData: Building SwiftUI Applications with Modern Approaches](https://fatbobman.com/en/posts/practical-swiftdata-building-swiftui-applications-with-modern-approaches/)
* [Concurrent Programming in SwiftData](https://fatbobman.com/en/posts/concurret-programming-in-swiftdata/)

## Key Features

- **Custom Executors for Core Data Actors**  
  CoreDataEvolution provides custom executors that ensure all operations on managed objects are performed on the appropriate thread associated with their managed object context. On iOS 17+/macOS 14+, it uses the modern `ExecutorJob` path; on earlier systems, it uses a compatible `UnownedJob` path.
  
- **@NSModelActor Macro**  
  The `@NSModelActor` macro simplifies Core Data concurrency, mirroring SwiftData’s `@ModelActor` macro. It generates the necessary boilerplate code to manage a Core Data stack within an actor, ensuring safe and efficient access to managed objects.
  
- **NSMainModelActor Macro**
  `NSMainModelActor` will provide the same functionality as `NSModelActor`, but it will be used to declare a class that runs on the main thread.

- **Elegant Actor-based Concurrency**  
  CoreDataEvolution allows you to create actors with custom executors tied to Core Data contexts, ensuring that all operations within the actor are executed serially on the context’s thread.

## Example Usage

Here’s how you can use CoreDataEvolution to manage concurrent Core Data operations with an actor:

```swift
import CoreDataEvolution

@NSModelActor
actor DataHandler {
    func updateItem(identifier: NSManagedObjectID, timestamp: Date) throws {
        guard let item = self[identifier, as: Item.self] else {
            throw MyError.objectNotExist
        }
        item.timestamp = timestamp
        try modelContext.save()
    }
}
```

In this example, the `@NSModelActor` macro simplifies the setup, automatically creating the required executor and Core Data stack inside the actor. Developers can then focus on their business logic without worrying about concurrency pitfalls.

This approach allows you to safely integrate modern Swift concurrency mechanisms into your existing Core Data stack, enhancing performance and code clarity.

You can disable the automatic generation of the constructor by using `disableGenerateInit`:

```swift
@NSModelActor(disableGenerateInit: true)
public actor DataHandler {
    let viewName: String

    func createNemItem(_ timestamp: Date = .now, showThread: Bool = false) throws -> NSManagedObjectID {
        let item = Item(context: modelContext)
        item.timestamp = timestamp
        try modelContext.save()
        return item.objectID
    }

    init(container: NSPersistentContainer, viewName: String) {
        modelContainer = container
        self.viewName = viewName
        let context = container.newBackgroundContext()
        context.name = viewName
        modelExecutor = .init(context: context)
    }
}
```

NSMainModelActor will provide the same functionality as NSModelActor, but it will be used to declare a class that runs on the main thread:

```swift
@MainActor
@NSMainModelActor
final class DataHandler {
    func updateItem(identifier: NSManagedObjectID, timestamp: Date) throws {
        guard let item = self[identifier, as: Item.self] else {
            throw MyError.objectNotExist
        }
        item.timestamp = timestamp
        try modelContext.save()
    }
}
```

## NSModelActor Protocol API

All actors decorated with `@NSModelActor` or `@NSMainModelActor` automatically gain the following properties and methods through the `NSModelActor` protocol extension.

### Properties

| Property | Description |
|---|---|
| `modelContext: NSManagedObjectContext` | The managed object context associated with this actor. All Core Data operations should go through this context. |
| `modelContainer: NSPersistentContainer` | The persistent container that owns this actor's context. |

### Subscript

Retrieve a managed object by its `NSManagedObjectID`, cast to the expected type. Returns `nil` if the object does not exist or the cast fails.

```swift
// Inside an actor method
guard let item = self[objectID, as: Item.self] else {
    throw MyError.objectNotFound
}
item.timestamp = .now
try modelContext.save()
```

### withContext

Provides direct, synchronous access to the actor's context (and optionally its container) from within the actor's isolation. The closure runs synchronously with no additional scheduling overhead.

This method is primarily intended for **unit tests** — use it to inspect the persistent store state after a write operation, without going through the actor's higher-level API.

```swift
// Verify state after a write — single-context overload
try await handler.withContext { context in
    let request = Item.fetchRequest()
    let items = try context.fetch(request)
    #expect(items.count == 1)
}

// Access both context and container — useful for cross-context verification
try await handler.withContext { context, container in
    let verificationContext = container.newBackgroundContext()
    let request = Item.fetchRequest()
    let items = try verificationContext.fetch(request)
    #expect(items.count == 1)
}
```

> **Note:** For production writes, prefer the actor's dedicated mutation methods so that save/rollback logic remains consistent.

## Testing Utilities

### NSPersistentContainer.makeTest

Creates an isolated, on-disk SQLite store for each test, avoiding the two most common pitfalls:

- **`/dev/null` (shared in-memory)**: all tests sharing the same URL read from and write to the same store — parallel execution causes data leakage and deadlocks.
- **Named in-memory stores**: WAL sidecar files (`.sqlite-shm`, `.sqlite-wal`) can linger between runs, producing phantom data.

`makeTest` solves this by using `#function` as the default `testName`, so each test automatically gets its own store file. Stale files from the previous run are deleted before the store loads.

```swift
@Test func createItem() async throws {
    // testName defaults to #function — each test gets its own store
    let container = NSPersistentContainer.makeTest(model: MySchema.objectModel)
    let handler = DataHandler(container: container)
    // … test body …
}
```

Parameters:

| Parameter | Type | Default | Description |
|---|---|---|---|
| `model` | `NSManagedObjectModel` | — | The managed object model for your schema. |
| `testName` | `String` | `#function` | Unique name for the store file; pass `#function` to auto-derive from the test name. |
| `subDirectory` | `String` | `"CoreDataEvolutionTestTemp"` | Temp sub-directory that holds the SQLite files. |

> **Note:** Store files are not deleted immediately after a test completes — they are cleaned up at the start of the *next* run with the same `testName`, so you can inspect them for debugging if needed.

## Installation

You can add CoreDataEvolution to your project using Swift Package Manager by adding the following dependency to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/fatbobman/CoreDataEvolution.git", .upToNextMajor(from: "0.7.0"))
]
```

Then, import the module into your Swift files:

```swift
import CoreDataEvolution
```

## System Requirements

- iOS 13.0+ / macOS 10.15+ / watchOS 6.0+ / visionOS 1.0+ / tvOS 13.0+
- Swift 6.0

Note: On iOS 17+/macOS 14+, the executor uses the `ExecutorJob` API. On earlier supported systems, it uses a compatible `UnownedJob` executor path.

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
