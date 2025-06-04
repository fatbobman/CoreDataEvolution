# ``CoreDataEvolution``

Revolutionizing Core Data with SwiftData-inspired Concurrent Operations

## Overview

CoreDataEvolution is a library aimed at modernizing Core Data by incorporating the elegance and safety of SwiftData-style concurrency. This library is designed to simplify and enhance Core Data's handling of multithreading, drawing inspiration from SwiftData's `@ModelActor` feature, enabling efficient, safe, and scalable operations.

## Motivation

SwiftData introduced modern concurrency features like `@ModelActor`, making it easier to handle concurrent data access with safety guaranteed by the compiler. However, SwiftData's platform requirements and limited maturity in certain areas have deterred many developers from adopting it. CoreDataEvolution bridges the gap, bringing SwiftData's advanced design into the Core Data world for developers who are still reliant on Core Data.

## Key Features

### Custom Executors for Core Data Actors

Using Swift 5.9's new `SerialExecutor` and `ExecutorJob` protocols, CoreDataEvolution provides custom executors that ensure all operations on managed objects are performed on the appropriate thread associated with their managed object context.

### @NSModelActor Macro

The `@NSModelActor` macro simplifies Core Data concurrency, mirroring SwiftData's `@ModelActor` macro. It generates the necessary boilerplate code to manage a Core Data stack within an actor, ensuring safe and efficient access to managed objects.

### NSMainModelActor Macro

`NSMainModelActor` provides the same functionality as `NSModelActor`, but is used to declare a class that runs on the main thread.

### Elegant Actor-based Concurrency

CoreDataEvolution allows you to create actors with custom executors tied to Core Data contexts, ensuring that all operations within the actor are executed serially on the context's thread.

## Basic Usage

Here's how you can use CoreDataEvolution to manage concurrent Core Data operations with an actor:

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

## Advanced Usage

### Custom Initialization

You can disable the automatic generation of the constructor by using `disableGenerateInit`:

```swift
@NSModelActor(disableGenerateInit: true)
public actor DataHandler {
    let viewName: String

    func createNewItem(_ timestamp: Date = .now, showThread: Bool = false) throws -> NSManagedObjectID {
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

### Main Thread Operations

NSMainModelActor provides the same functionality as NSModelActor, but for operations that need to run on the main thread:

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

## Installation

Add CoreDataEvolution to your project using Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/fatbobman/CoreDataEvolution.git", .upToNextMajor(from: "0.3.0"))
]
```

Then import the module:

```swift
import CoreDataEvolution
```

## System Requirements

- iOS 17.0+ / macOS 14.0+ / watchOS 10.0+ / visionOS 1.0+ / tvOS 17.0+
- Swift 6.0

> Important: Due to system limitations, custom executors and `SerialExecutor` are only available on iOS 17/macOS 14 and later.

## Topics

### Actors

- ``NSModelActor``
- ``NSMainModelActor``

### Executors

- Custom executors for Core Data contexts
- Thread-safe operations

### Migration

- Migrating from traditional Core Data patterns
- SwiftData compatibility considerations

