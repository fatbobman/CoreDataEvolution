# CoreDataEvolution

**Revolutionizing Core Data with SwiftData-inspired Concurrent Operations**

Welcome to CoreDataEvolution, a library aimed at modernizing Core Data by incorporating the elegance and safety of SwiftData-style concurrency. This library is designed to simplify and enhance Core Data’s handling of multithreading, drawing inspiration from SwiftData's `@ModelActor` feature, enabling efficient, safe, and scalable operations.

## Motivation

SwiftData introduced modern concurrency features like `@ModelActor`, making it easier to handle concurrent data access with safety guaranteed by the compiler. However, SwiftData's platform requirements and limited maturity in certain areas have deterred many developers from adopting it. CoreDataEvolution bridges the gap, bringing SwiftData’s advanced design into the Core Data world for developers who are still reliant on Core Data.

* [Core Data Reform: Achieving Elegant Concurrency Operations like SwiftData](https://fatbobman.com/en/posts/core-data-reform-achieving-elegant-concurrency-operations-like-swiftdata/)
* [Practical SwiftData: Building SwiftUI Applications with Modern Approaches](https://fatbobman.com/en/posts/practical-swiftdata-building-swiftui-applications-with-modern-approaches/)
* [Concurrent Programming in SwiftData](https://fatbobman.com/en/posts/concurret-programming-in-swiftdata/)

## Key Features

- **Custom Executors for Core Data Actors**  
  Using Swift 5.9's new `SerialExecutor` and `ExecutorJob` protocols, CoreDataEvolution provides custom executors that ensure all operations on managed objects are performed on the appropriate thread associated with their managed object context.
  
- **@NSModelActor Macro**  
  The `@NSModelActor` macro simplifies Core Data concurrency, mirroring SwiftData’s `@ModelActor` macro. It generates the necessary boilerplate code to manage a Core Data stack within an actor, ensuring safe and efficient access to managed objects.

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

## Installation

You can add CoreDataEvolution to your project using Swift Package Manager by adding the following dependency to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/fatbobman/CoreDataEvolution.git", .upToNextMajor(from: "0.3.0"))
]
```

Then, import the module into your Swift files:

```swift
import CoreDataEvolution
```

## System Requirements

- iOS 17.0+ / macOS 14.0+
- Swift 6.0

Note: Due to system limitations, custom executors and `SerialExecutor` are only available on iOS 17/macOS 14 and later.

## Contributing

We welcome contributions! Whether you want to report issues, propose new features, or contribute to the code, feel free to open issues or pull requests on the GitHub repository.

## License

CoreDataEvolution is available under the MIT license. See the LICENSE file for more information.

## Acknowledgments

Special thanks to the Swift community for their continuous support and contributions.

[![Buy Me A Coffee](https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png)](https://buymeacoffee.com/fatbobman)

