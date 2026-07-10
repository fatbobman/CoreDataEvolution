# CoreDataEvolution

CoreDataEvolution 为 Core Data 带来 Actor 隔离、Swift 优先的 `NSManagedObject` 声明、类型化路径、运行时 Schema 元数据与模型工具链。

![Swift](https://img.shields.io/badge/Swift-6.0%2B-orange?style=flat) ![Platforms](https://img.shields.io/badge/Platforms-iOS%2013%2B%20%7C%20macOS%2010.15%2B%20%7C%20tvOS%2013%2B%20%7C%20watchOS%206%2B%20%7C%20visionOS%201%2B-blue?style=flat) ![License](https://img.shields.io/badge/License-MIT-green?style=flat) [![DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/fatbobman/CoreDataEvolution)

[English](README.md) | 中文

## 动机

对于依赖成熟对象图、迁移能力与存储行为的应用，Core Data 仍是务实的基础设施，但其默认源码形态与并发模式和现代 Swift 之间已有距离。项目往往因此积累手写访问器、字符串查询键、上下文传递约定，以及模型与源码之间的偏移。

CoreDataEvolution 保留 Core Data 作为持久化引擎，同时让 Swift 层更明确、更易验证。它将 Actor 隔离访问、基于宏的 `NSManagedObject` 声明、类型化映射、可选的 Observation 支持，以及用于核对源码声明与真实模型的 CLI 汇集在一起。

延伸阅读：[为什么 2026 年了我仍在思考 Core Data](https://fatbobman.com/en/posts/why-i-am-still-thinking-about-core-data-in-2026/)

## 特性

- 使用 `@NSModelActor` 隔离后台工作，或通过 `@NSMainModelActor` 将面向 UI 的编排绑定到 `viewContext`。
- 使用 `@PersistentModel` 在 Swift 中声明 Core Data 实体，并显式描述属性、关系、组合与存储元数据。
- 为排序描述符和基于 `%K` 的谓词生成类型化键与路径，覆盖字段改名及关系路径。
- 在受支持的 Swift 与系统版本上，让生成的访问器选择加入 MainActor Observation。
- 为测试与调试构建运行时 Schema 和隔离的 SQLite 容器，同时不取代生产环境的 `.xcdatamodeld`。
- 使用 `cde-tool` 生成声明、验证模型与源码的一致性、检查模型并引导配置。

## 快速开始

通过 Swift Package Manager 将 CoreDataEvolution 添加到包中：

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

下面的可执行示例声明一个实体，创建用于测试与调试的运行时模型，并通过 MainActor 隔离的 `viewContext` 完成保存：

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

`makeRuntimeTest` 被刻意限定于测试和调试。生产应用应保留匹配的 Core Data 模型，并将已加载的 `NSPersistentContainer` 传给 `@NSModelActor` 或 `@NSMainModelActor` 类型。

## 延伸阅读

- 想以 Actor 隔离方式访问 Core Data？阅读 [NSModelActor 指南](Docs/NSModelActorGuide.md)。
- 想了解 Swift 优先的模型声明与生成成员？阅读 [PersistentModel 指南](Docs/PersistentModelGuide.md)。
- 想让 SwiftUI 观察生成的 Core Data 访问器？阅读 [Observation 指南](Docs/ObservationGuide.md)。
- 想构建类型安全的排序与谓词路径？阅读 [TypedPath 指南](Docs/TypedPathGuide.md)。
- 想选择合适的属性存储策略？阅读 [存储方式指南](Docs/StorageMethodGuide.md)。
- 想通过 CLI 生成或验证声明？阅读 [cde-tool 指南](Docs/CDEToolGuide.md)。
- 想了解 CLI 当前的能力边界？阅读 [cde-tool 已知限制](Docs/CDEToolKnownLimitations.md)。

## 要求

- MainActor Observation 需要 Swift 6.2+ 编译器，以及 iOS 17+、macOS 14+、tvOS 17+、watchOS 10+ 或 visionOS 1+。
- Core Data 组合属性需要 iOS 17+、macOS 14+、tvOS 17+、watchOS 10+ 或 visionOS 1+。

## 贡献与测试

提交 Issue 或 Pull Request 前，请先阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。本地验证从 `swift build` 与 `bash Scripts/run-tests.sh` 开始；安全敏感问题请依照 [SECURITY.md](SECURITY.md) 报告。

## 许可证

CoreDataEvolution 采用 MIT 许可证，详情请参阅 [LICENSE](LICENSE)。

## Author

**Fatbobman (肘子)** — Blog: [fatbobman.com](https://fatbobman.com) · X: [@fatbobman](https://x.com/fatbobman)

## Support

If this project helps you, please consider supporting my work:

- 📮 Subscribe to [Fatbobman's Swift Weekly](https://weekly.fatbobman.com) — fresh Swift and Apple-ecosystem insights every week
- ☕️ [Buy Me a Coffee](https://buymeacoffee.com/fatbobman)
