# NSModelActor Guide

`@NSModelActor` and `@NSMainModelActor` bring SwiftData-style isolation patterns to Core Data
without requiring SwiftData itself.

This guide is written for library users. It explains:

- when to use each macro
- what code the macros generate
- how to structure your actor or main-actor type
- how to use the convenience APIs
- how to test these types safely
- which constraints are intentional in the current implementation

`CoreDataEvolution` re-exports `CoreData`, so normal use sites usually only need:

```swift
import CoreDataEvolution
```

You do not normally need a separate `import CoreData`.

## Choose the Right Macro

Use `@NSModelActor` when the type should own a private Core Data context and serialize its work
through an actor.

```swift
import CoreDataEvolution

@NSModelActor
actor ItemStore {
  func createItem(timestamp: Date) throws -> NSManagedObjectID {
    let item = Item(context: modelContext)
    item.timestamp = timestamp
    try modelContext.save()
    return item.objectID
  }
}
```

Use `@NSMainModelActor` when the type should always operate on `viewContext` from the main actor.

```swift
import CoreDataEvolution

@MainActor
@NSMainModelActor
final class ItemViewModel {
  func createItem(timestamp: Date) throws {
    let item = Item(context: modelContext)
    item.timestamp = timestamp
    try modelContext.save()
  }
}
```

Rule of thumb:

- `@NSModelActor`: background work, isolated writes, actor-based APIs
- `@NSMainModelActor`: UI-facing orchestration that must stay on the main actor

## What `@NSModelActor` Generates

For an actor declaration:

```swift
@NSModelActor
actor ItemStore {}
```

the macro adds:

- `nonisolated let modelExecutor: NSModelObjectContextExecutor`
- `nonisolated let modelContainer: NSPersistentContainer`
- `init(container: NSPersistentContainer)` unless disabled
- `NSModelActor` conformance

The generated initializer always uses:

```swift
let context = container.newBackgroundContext()
```

That is an intentional behavior contract in this package.

## What `@NSMainModelActor` Generates

For a class declaration:

```swift
@MainActor
@NSMainModelActor
final class ItemViewModel {}
```

the macro adds:

- `let modelContainer: NSPersistentContainer`
- `init(modelContainer: NSPersistentContainer)` unless disabled
- `NSMainModelActor` conformance

`modelContext` is not stored directly. The protocol extension always resolves it as:

```swift
modelContainer.viewContext
```

## Generated Convenience APIs

Both protocols expose a small convenience surface.

### `modelContext`

The context that should be used by your methods.

- `NSModelActor`: the context wrapped by `modelExecutor`
- `NSMainModelActor`: `viewContext`

### Typed subscript

Load an object by `NSManagedObjectID` and expected type:

```swift
guard let item = self[itemID, as: Item.self] else {
  throw StoreError.itemNotFound
}
```

This is useful when the caller only has an object ID and the actor should rehydrate the object
inside its own isolation domain.

### `withContext`

Two overloads are available on both protocols:

```swift
try await handler.withContext { context in
  // inspect or query the actor's context
}

try await handler.withContext { context, container in
  // inspect the context and also access the container
}
```

These APIs are primarily for:

- tests
- debugging
- verification queries that do not deserve a dedicated production API

They are synchronous closures executed inside the type's existing isolation boundary. They do not
create a new scheduling layer.

For production writes, prefer dedicated mutation methods on the actor or class instead of exposing
raw context access everywhere.

## Custom Initializers

If you need extra stored properties or a custom context setup, disable initializer generation:

```swift
@NSModelActor(disableGenerateInit: true)
actor ItemStore {
  let viewName: String

  init(container: NSPersistentContainer, viewName: String) {
    modelContainer = container
    self.viewName = viewName

    let context = container.newBackgroundContext()
    context.name = viewName
    modelExecutor = .init(context: context)
  }
}
```

For `@NSMainModelActor`:

```swift
@MainActor
@NSMainModelActor(disableGenerateInit: true)
final class ItemViewModel {
  let screenName: String

  init(modelContainer: NSPersistentContainer, screenName: String) {
    self.modelContainer = modelContainer
    self.screenName = screenName
  }
}
```

When you disable the generated initializer, you are responsible for assigning every generated
stored property correctly.

For `@NSModelActor`, that means:

- `modelContainer`
- `modelExecutor`

For `@NSMainModelActor`, that means:

- `modelContainer`

## Testing Patterns

### Use `NSPersistentContainer.makeTest`

For schema-backed tests, prefer:

```swift
let container = try NSPersistentContainer.makeTest(model: MySchema.objectModel)
```

This helper intentionally:

- uses an on-disk SQLite store and clears stale files before loading
- deletes stale sidecar files before loading
- serializes container creation and `loadPersistentStores`

Treat this helper as a one-shot test container by default:

- the default name comes from the call site (`#fileID` + `#function`)
- that is usually the right choice for one container per test method
- if one test method needs multiple containers, pass distinct `testName` values

This SQLite-backed approach is intentional:

- it avoids the shared-state and deadlock risks of `/dev/null`
- it exercises a more realistic SQLite + WAL setup than shared in-memory stores
- in heavily parallel suites, it is often more robust than shared in-memory approaches

Do not switch back to `/dev/null` or a shared in-memory URL.

### Use `withContext` for assertions

In tests, the recommended pattern is:

1. call the actor's public API
2. verify state with `withContext`

Example:

```swift
let stack = try TestStack()
let handler = DataHandler(container: stack.container, viewName: "test")

_ = try await handler.createItem(timestamp: .now)

let count = try await handler.withContext { context in
  let request = Item.fetchRequest()
  return try context.fetch(request).count
}

#expect(count == 1)
```

This keeps the mutation path realistic while still allowing direct assertions.

### Runtime-model tests

If you are testing macro-generated runtime schema instead of `.xcdatamodeld`, use:

```swift
let container = try NSPersistentContainer.makeRuntimeTest(modelTypes: Item.self, Tag.self)
```

That path is intended for test and debug workflows only. It is not a replacement for production
Core Data model versioning.

## Visibility Rules

The macros mirror the attached type's visibility for generated members.

One special case exists:

- if the attached type is `private` or `fileprivate`
- generated witness members use `fileprivate`

That is required so the synthesized conformance extension can still see the witnesses.

## Required Source Rules

### `@NSModelActor`

- attach it to an `actor`
- if you disable init generation, assign `modelContainer` and `modelExecutor` yourself
- the generated default initializer always uses `newBackgroundContext()`

### `@NSMainModelActor`

- attach it to a `class`
- mark the type `@MainActor`
- if you disable init generation, assign `modelContainer` yourself
- the type always uses `viewContext`

`@MainActor` remains a source-level requirement. The macro does not silently rewrite the attached
type's isolation attributes for you.

## Common Mistakes

### Forgetting `@MainActor` on `@NSMainModelActor`

Bad:

```swift
@NSMainModelActor
final class ItemViewModel {}
```

Good:

```swift
@MainActor
@NSMainModelActor
final class ItemViewModel {}
```

The macro does not currently enforce `@MainActor` itself. This is still a source-level rule you
should follow rather than something the macro silently rewrites on your behalf.

### Disabling init generation without assigning generated members

Bad:

```swift
@NSModelActor(disableGenerateInit: true)
actor ItemStore {
  init(container: NSPersistentContainer) {}
}
```

Good:

```swift
@NSModelActor(disableGenerateInit: true)
actor ItemStore {
  init(container: NSPersistentContainer) {
    modelContainer = container
    modelExecutor = .init(context: container.newBackgroundContext())
  }
}
```

### Treating `withContext` as the main production API

`withContext` is intentionally low-level. Use it for tests and debugging, not as a replacement for
clear domain methods.

Prefer:

```swift
try await store.updateTimestamp(id: itemID, to: .now)
```

over exposing every operation through raw context closures.

## Recommended Structure

For background actors:

- keep public methods small and task-oriented
- load objects inside the actor by object ID
- save explicitly after mutations
- use `withContext` only for assertions or debugging

For main-actor handlers:

- keep UI coordination on the main actor
- reserve heavy write flows for background actors when appropriate
- use the same `NSPersistentContainer` when the UI and background actors need to cooperate

## Current Boundaries

These are intentional in the current design:

- `@NSModelActor` uses `newBackgroundContext()` by default
- `@NSMainModelActor` uses `viewContext`
- `withContext` is synchronous within the current isolation domain
- the package does not try to hide raw Core Data save semantics
- test helpers prioritize store isolation and parallel-suite stability over in-memory convenience

## Relationship to the README

This guide is the detailed reference for the actor macros and testing helpers.

The README can stay shorter and focus on:

- what the library does
- why the actor macros exist
- a minimal usage example
- links to this guide for the full workflow
