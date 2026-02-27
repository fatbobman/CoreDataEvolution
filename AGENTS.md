# CoreDataEvolution — Agent Guide

Brings SwiftData-style concurrency (`@ModelActor`) to Core Data via a macro + custom executor. No runtime dependencies; `swift-syntax` is build-time only.

## Platform Constraints

- Minimum deployment: iOS 13 / macOS 10.15 / watchOS 6 / visionOS 1.0 / tvOS 13
- Swift 6 strict concurrency — do not use APIs gated behind iOS 17+ / macOS 14+ without an availability check

## Core API

### `@NSModelActor` macro

Mirrors SwiftData's `@ModelActor`. Generates `modelContainer`, `modelExecutor`, and a default `init(container:)` (background context). Use `disableGenerateInit: true` to provide a custom initializer:

```swift
@NSModelActor(disableGenerateInit: true)
actor DataHandler {
    let tag: String
    init(container: NSPersistentContainer, tag: String) {
        modelContainer = container
        self.tag = tag
        modelExecutor = .init(context: container.newBackgroundContext())
    }
}
```

### `@NSMainModelActor` macro

Main-thread variant for classes. Generates `modelContainer` and a default `init(modelContainer:)`, and binds `modelContext` to `viewContext`. Requires `@MainActor` on the class:

```swift
@MainActor
@NSMainModelActor
final class MainHandler { … }
```

### `NSModelActor` protocol extension (`@NSModelActor` types)

| API | Description |
|---|---|
| `modelContext` | The actor's `NSManagedObjectContext`. |
| `modelContainer` | The `NSPersistentContainer`. |
| `self[id, as: T.Type] -> T?` | Fetch by `NSManagedObjectID`, cast to `T`. |
| `withContext { context in }` | Synchronous closure on the actor's context. For tests. |
| `withContext { context, container in }` | Same, also exposes the container. |

### `NSPersistentContainer.makeTest(model:testName:subDirectory:)`

Isolated on-disk SQLite store for tests. Deletes stale `.sqlite`/`.sqlite-shm`/`.sqlite-wal` before loading. `testName` defaults to `#fileID-#function` — each test call site gets its own store. Never use `/dev/null` (shared store causes deadlocks under parallel execution).

```swift
@Test func myTest() async throws {
    let container = NSPersistentContainer.makeTest(model: MyModel.objectModel)
    let handler = DataHandler(container: container, tag: "test")
    …
}
```

## NSManagedObjectModel

Always expose as `static let` — multiple instances from the same `.momd` crash on store registration. Use `@preconcurrency import CoreData` to suppress the Swift 6 `Sendable` warning:

```swift
@preconcurrency import CoreData

enum ModelConfiguration {
    static let objectModel: NSManagedObjectModel = {
        let url = Bundle.main.url(forResource: "MyModel", withExtension: "momd")!
        return NSManagedObjectModel(contentsOf: url)!
    }()
}
```
