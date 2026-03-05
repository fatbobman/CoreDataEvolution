# Keys + Paths + Lookup Table POC

这个目录是独立技术验证，不接入主库 target，目标是验证 v1 设计中的基础机制：

- `Keys`: 平面字段排序入口（支持 renamed 字段）
- `Paths`: 子路径排序入口（relationship / composition）
- `__cdFieldTable`: `swiftPath -> persistentPath + storageMethod` 的统一查找表

## 如何运行

```bash
cd Research/KeysPathsLookupPOC
swift test
```

## 源码结构

- `ModelMetadata.swift`
  - 基础模型元数据：`StorageMethod`、`CDFieldMeta`、`CDPath`
- `CompositionSupport.swift`
  - composition 元数据契约：`CDCompositionPathProviding`、`CDCompositionTableBuilder`
- `PathProtocols.swift`
  - 路径协议与查表入口：`CoreDataPathTable`、`CoreDataKeys`、`CoreDataPathDSLProviding`
- `Sorting.swift`
  - 排序层：`Sort*` 枚举、`CDSortDescriptorError`、`NSSortDescriptor` typed init
- `Filtering.swift`
  - 过滤层：`CDFilterField` 与 `CDPath` 的 `NSPredicate` 构建扩展
- `ToManyFilterPaths.swift`
  - 对多关系量词 DSL：`CDToManyRelationPath`、`CDQuantifiedToManyPath`

## 本次验证覆盖

- `NSSortDescriptor(Object.self, key: .date, ...)` 正确落到持久化键（例如 `date -> timestamp`）
- `NSSortDescriptor(Object.self, path: Item.path.magnitude.richter, ...)` 支持 composition 子路径
- relationship 子路径（`category.name`）可直接映射为持久化路径
- to-many predicate 量词路径：`Model.path.tags.any/all/none.<field>`
- `__cdFieldTable` 可作为 future predicate 路径映射的基础入口
- composition 静态字段表可由主宏直接消费（无需反射）
- 排序执行模式约束：
  - `storeCompatible` 下仅允许 `storeDefault` collation
  - 非 store-sortable 字段（如 `.codable`）在 `storeCompatible` 下拒绝
  - `inMemory` 下允许本地化比较（`localized` / `localizedStandard`）

## 路径 DSL（当前实现）

当前 POC 已实现统一的点号链式路径访问（`.`）：

- 常规（非 composition）场景：`Model.path.name`
- composition 场景：`Model.path.location.x`
- to-many predicate 场景：`Model.path.tags.any.name` / `Model.path.tags.all.score` / `Model.path.tags.none.name`

设计原则：

- 大多数模型使用最短路径写法（`Model.path.<field>`）
- 在 v1 起点就保证 composition 能平滑扩展到多级子路径
- `sort` 与未来 predicate 共用同一套路径与查找表元信息（`__cdFieldTable`）

当前限制：

- 该 DSL 仍是“宏生成静态结构”形态，不依赖运行时反射
- predicate 转换层尚未实现，但映射基础（`__cdFieldTable`）已就位
- sort 明确不支持 to-many 关系路径（项目约定）

## Composition 宏前提验证

- `@Composition` 需要生成静态字段表（此 POC 中用 `CDCompositionPathProviding` 模拟）
- 主宏可通过 `CDCompositionTableBuilder` 将 `composition` 的字段表拼接到模型路径表
- 该路径不依赖运行时反射，规避访问权限和动态成员枚举限制

## 对多关系 Predicate 方案

核心结构：

- `CDToManyRelationPath<Root, Target>`
- `CDQuantifiedToManyPath<Root, Target>`
- `CDFilterField<Root, Value>`

语法示例：

```swift
let p1 = Item.path.tags.any.name.equals("Swift")
let p2 = Item.path.tags.all.score.greaterThan(80)
let p3 = Item.path.tags.none.name.contains("legacy")

let final = NSCompoundPredicate(
  andPredicateWithSubpredicates: [p1, Item.path.title.contains("Core Data")]
)
```

语义映射：

- `.any` -> `ANY tags.<field> ...`
- `.all` -> `NOT (ANY tags.<field> <inverse-op> ...)`（等价展开，规避直接 `ALL` 的兼容性问题）
- `.none` -> `NOT (ANY tags.<field> ...)`（避免依赖 `NONE` 关键字解析）

## 结论

这套结构可以作为 `sortDescriptor` 和未来 predicate 转换层的共同基座，特别是 composition 场景下，`Paths + __cdFieldTable` 能保持：

- 调用侧类型安全（不依赖裸字符串）
- 持久化路径映射集中管理
- 排序/谓词共享同一份元信息来源
