# CoreData 改善层设计笔记

## 背景与目标

不替换 Core Data 的现有工作流（xcdatamodeld 继续存在），而是在 `NSManagedObject` 之上提供一层薄的改善层，解决以下痛点：

本项目还有一个同等重要的目标：**并非仅仅简化/强化表现层**，而是通过宏约束、生成代码与校验工具，沉淀一套可执行的 Core Data 开发范式，推动团队写出符合 Swift 6 时代习惯的模型代码。

- `@NSManaged` 不支持 `Int?`、`Double?` 等 Swift 原生类型，只能用 `NSNumber?`
- 持久化字段命名不合适时，无法在不影响存储的情况下对外暴露新名称
- 构建 `NSSortDescriptor` 时无法使用 KeyPath，只能用裸字符串
- 谓词构建中大量裸字符串，缺乏类型安全保障

### 为什么不直接用 SwiftData

SwiftData 采用纯代码声明模型，看似更符合 Swift 习惯，但在模型多版本迭代时暴露出一个明显问题：每个历史版本都需要保留一份对应的 Swift 模型代码，随着版本迭代只增不减，项目中会堆积大量历史版本的模型文件。虽然可以通过 `typealias` 指定当前版本，但代码库的整洁度持续下降。

相比之下，xcdatamodeld 将所有版本内聚在一个 bundle 内管理，Xcode 提供可视化的版本对比，迁移路径也更清晰。Core Data 围绕 xcdatamodeld 版本差异构建的迁移体系（lightweight migration、migration plan）经过十几年打磨，非常可靠。

因此本方案的策略是：

- **数据层**（存储、迁移、版本管理）完全交给 Core Data，不动
- **代码层**（Swift 侧如何声明和访问属性）做符合 Swift 习惯的改善

代价是 Swift 代码和 xcdatamodeld 模型定义之间可能出现不对齐，这个问题通过配套的外部校验工具来弥补。

**最终目标**：通过宏自动生成所有样板代码，开发者只需声明计算属性本身。

### 测试 / 调试用 Runtime Schema（新增目标）

除基于 `xcdatamodeld` 的正式工作流外，本项目还计划提供一套**仅用于测试/调试**的 runtime schema 能力：

- 由宏为 `@PersistentModel` 生成静态 schema metadata
- 在测试、CLI、SPM、AI 生成代码等非 Xcode 场景中，直接由 `[Item.self, Tag.self]` 组装 `NSManagedObjectModel`
- 目标是降低测试搭建成本，而不是替代 xcdatamodeld

这里的定位必须明确：

- 它是“方便开发”的辅助能力，不是生产建模能力
- 不要求与 `xcdatamodeld` 的 hash、version、migration 语义保持一致
- 不处理历史模型版本
- 不依赖运行时反射，只消费宏生成的静态 metadata

当前 runtime schema v1 还包含三条明确边界：

- relationship metadata 以显式 `@Relationship(persistentName:inverse:deleteRule:)` 为真值，不依赖 inverse 推断。
- primitive 默认值只支持一组可稳定翻译到 `NSAttributeDescription.defaultValue` 的表达式子集；无法稳定翻译时直接报错，不做静默降级。
- composition 在 runtime schema / runtime builder 中按单个 transformable dictionary payload 建模，遵循宏生成的 composition accessor 契约，不等价于 xcdatamodeld 的展平字段布局。

另外，以下 Core Data 模型元数据当前不支持通过源码声明进入 pure-code model：

- `allowsExternalBinaryDataStorage`
- `spotlight`
- `preserveValueOnDeletion`
- `valueRange`
- `dateRange`

这些限制只影响 runtime schema / pure-code test model，不影响正式的 `xcdatamodeld` 工作流。

之所以可以这样设计，是因为当前范式已经主动收紧了模型表达范围：

- 持久化 attribute 必须“可选或有默认值”
- relationship 必须 optional，且必须有 inverse
- composition 结构和字段类型都受宏约束

这些规则足以支撑测试模型的纯代码构建。

### 前提条件

xcdatamodeld 中每个 Entity 的 **Codegen 必须设置为 Manual/None**。

Xcode 提供三种 Codegen 模式：

| 模式 | 行为 |
|---|---|
| **Manual/None** | 不自动生成任何代码，开发者完全手动控制 ✅ |
| Class Definition | 自动生成完整的 `NSManagedObject` 子类 |
| Category/Extension | 自动生成属性 extension，保留手写类定义 |

使用本方案时必须选择 Manual/None，否则 Xcode 自动生成的 `@NSManaged` 属性会与手写的计算属性产生冲突。

该条件由工具强制校验：发现 Entity 的 Codegen 不是 Manual/None 时，`validate` 与 `generate` 都直接报错。

---

## 核心机制：用计算属性替代 @NSManaged

通过 KVC (`value(forKey:)` / `setValue(_:forKey:)`) 手动实现 getter/setter，替代 `@NSManaged`。`@NSManaged` 本质上也是基于 KVC 的语法糖。

```swift
@objc(Item)
final class Item: NSManagedObject, Identifiable {
    // 对外暴露 `date`，底层持久化字段名为 `timestamp`
    var date: Date? {
        get { value(forKey: "timestamp") as? Date }
        set { setValue(newValue, forKey: "timestamp") }
    }
}
```

---

## 关系（Relationship）

### 识别机制

`@PersistentModel` 仍通过属性类型识别关系的基数：

- `T?` -> to-one
- `Set<T>` -> unordered to-many
- `[T]` -> ordered to-many

但关系元数据不再依赖推断。每个 relationship 都必须显式写出：

```swift
@Relationship(persistentName: "category_ref", inverse: "items", deleteRule: .nullify)
var category: Category?
```

### 声明示例

```swift
@PersistentModel
final class Item: NSManagedObject, Identifiable {

    @Attribute(persistentName: "timestamp")
    var date: Date?

    @Relationship(persistentName: "tags", inverse: "items", deleteRule: .cascade)
    var tags: Set<Tag>

    @Relationship(persistentName: "category_ref", inverse: "items", deleteRule: .nullify)
    var category: Category?
}
```

### 可选性规则

为消除歧义，强制约定可选性，宏遇到违规声明时**编译期报错**：

| 属性类型 | 规则 | 原因 |
|---|---|---|
| 对多（`Set<T>`、`[T]`）| **强制非可选** | `nil` 与空集合语义无实质区别，统一用空集合表达"无数据" |
| 对一（`T?`）| **强制可选** | 底层随时可能为 `nil`，非可选无法安全表达 |

```swift
var tags: Set<Tag>    // ✅ 无序对多
var tags: Set<Tag>?   // ❌ 编译期报错

var category: Category?   // ✅ 对一
var category: Category    // ❌ 编译期报错
```

模型层与代码层的约束分离如下：

- **模型层（xcdatamodeld）**：对多关系必须 `Optional = true`（硬性要求）
- **代码层（Swift）**：对多关系必须非可选（`Set<T>` / `[T]`）
- 语义约定：运行时把模型层的 `nil` 对多统一映射为代码层空集合 `[]`

该约束用于建立统一范式与同步兼容性。如果现有模型中存在“对多关系 Optional=false”，默认视为不兼容，无法直接转换到本规范代码。

### 宏展开逻辑

宏从属性类型推断关系类型和生成内容：

| 属性类型 | 识别为 | 底层类型 | 生成内容 |
|---|---|---|---|
| `Set<T>` 且 T 符合 `PersistentEntity` | 无序对多 | `NSSet` | getter（`?? []`）+ 单个/批量增删便利方法，**不生成 setter** |
| `[T]` 且 T 符合 `PersistentEntity` | 有序对多 | `NSOrderedSet` | getter（`?? []`）+ 单个/批量增删便利方法 + `insertInto*(_:at:)`，**不生成 setter** |
| `T?` 且 T 符合 `PersistentEntity` | 对一 | 直接引用 | getter/setter |

**无序对多展开示例**：

```swift
// var tags: Set<Tag> 展开后
var tags: Set<Tag> {
    get {
        (value(forKey: "tags") as? NSSet)?
            .compactMap { $0 as? Tag }
            .reduce(into: Set()) { $0.insert($1) }
            ?? []
    }
}

func addToTags(_ tag: Tag) {
    mutableSetValue(forKey: "tags").add(tag)
}

func removeFromTags(_ tag: Tag) {
    mutableSetValue(forKey: "tags").remove(tag)
}

func addToTags(_ tags: Set<Tag>) {
    let mutable = mutableSetValue(forKey: "tags")
    for tag in tags {
        mutable.add(tag)
    }
}

func removeFromTags(_ tags: Set<Tag>) {
    let mutable = mutableSetValue(forKey: "tags")
    for tag in tags {
        mutable.remove(tag)
    }
}
```

对多关系相关代码的生成行为当前是固定的：

```swift
@PersistentModel(
)
```

- 对多 getter（`Set<T>` / `[T]`）当前固定生成，不提供独立策略开关。
- 不生成任何 `*Count` 访问器，建议使用 `NSManagedObjectContext.count(for:)` + `NSPredicate`。
- 所有对多关系都不生成 setter，统一通过便利方法进行关系修改。
- `Set<T>` 生成单个和批量 `add/remove` 便利方法。
- `[T]` 生成单个和批量 `add/remove`，以及 `insertInto*(_:at:)` 便利方法。

### 关系支持 `persistentName`

关系现在支持通过 `@Relationship(persistentName:)` 映射底层关系名。

这与 `@Attribute(persistentName:)` 的设计目标一致：

- Swift 属性名可以服务业务表达
- Core Data 模型中的持久化关系名可以保持稳定
- typed path / sort / `%K` predicate 仍然通过映射自动落到真实的持久化 key path

需要特别注意：

- `persistentName` 表示“当前关系在模型中的名字”
- `inverse` 表示“对端关系在模型中的持久化名字”
- `inverse` **不是**对端 Swift 属性名

| | 属性 | 关系 |
|---|---|---|
| Swift 侧命名 | 可自定义（对外名） | 可自定义（对外名） |
| 底层名映射 | `@Attribute(persistentName:)` | `@Relationship(persistentName:)` |
| 改名方式 | 代码层映射 | 代码层映射 |
| 宏是否需要标注 | 是（`persistentName:`）| 需要时标注（`persistentName:`） |
| 工具检查内容 | Swift 名 → 持久化名是否存在 | Swift 名 → 持久化关系名是否存在，且 `inverse` 指向对端持久化关系名 |

### 自动生成构造方法

`@PersistentModel` 默认不生成构造方法；可通过 `generateInit: true` 开启。开启后会将所有非关系实例存储属性作为参数列出（包含 `@Ignore`）。

**规则**：
- 参数一律不带默认值，调用方必须显式传入
- **关系不出现在参数列表里**（构造方法不接收任何关系数据）
- 构造方法不接收 `context` 参数
- 构造方法内部统一使用 `self.init(entity: Self.entity(), insertInto: nil)` 创建实例
- 创建后必须由调用方显式 `context.insert(...)`
- 关系必须在“双方实例都已创建且都已 `insert`”之后，再通过关系方法显式关联

```swift
// 宏生成（便捷 init）
extension Item {
    convenience init(
        date: Date,
        price: Double,
        note: String?
        // 关系不出现在参数列表
    ) {
        self.init(entity: Self.entity(), insertInto: nil)
        self.date = date
        self.price = price
        self.note = note
    }
}
```

**推荐的两阶段创建流程**：

```swift
// 第一阶段：创建实例并 insert
let tag = Tag(name: "Swift")
context.insert(tag)

let item = Item(date: .now, price: 9.9, note: nil)
context.insert(item)

// 第二阶段：建立关系（必须在双方都 insert 之后）
item.addToTags(tag)

try context.save()
```

这种方式强制要求开发者先准备好所有必要数据，显式 insert 后再建立关系，是实践中最稳妥的 Core Data 使用方式。也与 SwiftData 的创建语义一致：创建对象不自动插入上下文，插入时机由调用方控制。

> 强约束：禁止在构造方法中传递或建立任何关系；关系关联只能发生在“对象已创建 + 已 insert”之后。

### 职责边界

模型层仍然是底层真值来源，但 relationship 的源码表现层也必须完整声明：

- `inverse`
- `deleteRule`
- ordered / unordered 仍由属性类型表达

校验工具负责检查 Swift 侧 `@Relationship(...)` 与模型文件是否对齐。

硬性要求：模型中的每一条 relationship 都必须配置 inverse。缺失 inverse 视为不符合本规范，校验阶段直接报错。

### 有序对多关系

xcdatamodeld 中勾选 "Ordered" 的对多关系，底层为 `NSOrderedSet`，Swift 侧对应 `Array`：

```swift
@Relationship(inverse: "items", deleteRule: .cascade)
var tags: [Tag]     // 有序对多，底层 NSOrderedSet

@Relationship(inverse: "items", deleteRule: .cascade)
var tags: Set<Tag>  // 无序对多，底层 NSSet
```

`@PersistentModel` 宏通过属性类型识别有序/无序：

| 属性类型 | 识别为 | 底层类型 |
|---|---|---|
| `Set<T>` 且 T 符合 `PersistentEntity` | 无序对多 | `NSSet` |
| `[T]` 且 T 符合 `PersistentEntity` | 有序对多 | `NSOrderedSet` |
| `T?` 且 T 符合 `PersistentEntity` | 对一 | 直接引用 |

**有序对多展开示例**：

```swift
// var tags: [Tag] 展开后
var tags: [Tag] {
    get {
        (value(forKey: "tags") as? NSOrderedSet)?.array.compactMap { $0 as? Tag } ?? []
    }
}

func addToTags(_ tag: Tag) {
    mutableOrderedSetValue(forKey: "tags").add(tag)
}

func removeFromTags(_ tag: Tag) {
    mutableOrderedSetValue(forKey: "tags").remove(tag)
}

func addToTags(_ tags: [Tag]) {
    let mutable = mutableOrderedSetValue(forKey: "tags")
    for tag in tags {
        mutable.add(tag)
    }
}

func removeFromTags(_ tags: [Tag]) {
    let mutable = mutableOrderedSetValue(forKey: "tags")
    for tag in tags {
        mutable.remove(tag)
    }
}

func insertIntoTags(_ tag: Tag, at index: Int) {
    mutableOrderedSetValue(forKey: "tags").insert(tag, at: index)
}
```


**两侧一致性校验**：工具同时检查以下两点，任一不一致均报错：

- xcdatamodeld 中 Ordered 勾选状态与 Swift 侧属性类型是否一致
- `@Relationship` 中的 `inverse/deleteRule` 与模型是否一致

```
[ERROR] Item.tags: ordered relationship must use Array<T>, found Set<Tag>
[ERROR] Item.tags: deleteRule mismatch — model has cascade, source declares nullify
```

### 校验策略

`@Relationship(...)` 不是可选信息，而是 relationship 声明的一部分。工具必须始终校验：

- `inverse`
- `deleteRule`
- ordered/unordered 与属性类型的一致性

无论源码如何声明，工具都会强制检查模型层 inverse 是否配置；缺失 inverse 一律为 `[ERROR]`。
v1 不自动生成 `*Count`；若需要数量，推荐通过 `NSManagedObjectContext.count(for:)` + `NSPredicate` 计算。

---

## 访问权限规则

### 宏生成代码的权限继承

宏生成的所有代码（计算属性、便利方法、`Keys` 枚举、构造方法等）**严格继承类型本身的访问权限**，不会自动提升或降低。

```swift
// 声明为 public
public final class Item: NSManagedObject {
    @Attribute(persistentName: "timestamp")
    public var date: Date?       // 宏生成 public 的 getter/setter
}

// 声明为 internal（默认）
final class Item: NSManagedObject {
    @Attribute(persistentName: "timestamp")
    var date: Date?              // 宏生成 internal 的 getter/setter
}
```

宏生成的附属内容同样跟随：

```swift
public final class Item: NSManagedObject {
    // 宏生成的 Keys / Paths / 查找表
    public enum Keys: String { ... }
    public enum Paths { ... }
    internal static let __cdFieldTable: [String: CDFieldMeta] = ...

    // 宏生成的构造方法
    public convenience init(...) { ... }

    // 宏生成的关系便利方法
    public func addToTags(_ tag: Tag) { ... }
    // v1 不自动生成 tagsCount，需使用 context.count(for:)
}
```

### 工具生成代码的权限设置

工具生成初始代码时，通过参数指定权限，默认为 `public`：

```bash
# 默认 public
swift package generate-coredata-model --entity Item

# 指定权限
swift package generate-coredata-model --entity Item --access-level internal
```

生成的代码中类和属性声明均带对应的访问修饰符，开发者可以在生成后按需调整。

---

## @Ignore：标记非持久化属性

### 用途

`@PersistentModel` 仅处理参与持久化的 `var` 属性；`let` 属性默认忽略，不参与持久化生成。`@Ignore` 用于标记应被跳过的 `var`（纯内存状态），宏遇到此标注时不生成任何访问器代码。

```swift
@PersistentModel
final class Item: NSManagedObject {

    @Attribute(persistentName: "timestamp")
    var date: Date?

    @Ignore
    var isSelected: Bool = false    // 纯内存状态，UI 选中态等

    @Ignore
    var formattedDate: String {     // 计算属性，基于持久化属性派生
        date?.formatted() ?? ""
    }

    let debugID = UUID()            // let 默认忽略，无需 @Ignore
}
```

### 与 SwiftData @Transient 的区别

SwiftData 提供 `@Transient` 宏，对应 Core Data 模型里的 transient 属性（不持久化但受 undo/redo 追踪）。本方案在 v1 不新增单独 `@Transient` 宏，而是统一采用 `@Attribute(.transient, ...)` trait 写法：

```swift
@Attribute(.transient, persistentName: "cached_summary")
var cachedSummary: String = ""
```

| | SwiftData `@Transient` | 本方案 |
|---|---|---|
| transient 属性声明 | 在代码里用宏标注 | 在代码里用 `@Attribute(.transient, ...)` 标注，并要求模型也声明为 transient |
| 纯内存属性 | 不需要标注（不声明即不持久化）| 需要 `@Ignore` 告知宏跳过 |

这里要区分两种语义：

- `@Attribute(.transient, ...)`
  - 仍然属于 Core Data 模型的一部分
  - 只是 `isTransient = true`，不落库
- `@Ignore`
  - 完全不进入 Core Data 模型
  - 仅用于纯 Swift 内存属性

v1 约束：

- `transient` 仅允许与 `.default` 存储配合使用
- 暂不支持与 `.raw` / `.codable` / `.transformed` / `.composition` 混用
- tooling 的 `generate` / `validate` 需要识别并校验该 trait
- 不支持 Derived Attribute（派生属性）；若模型中存在派生属性，`validate` 必须报错，`generate` 必须拒绝继续

---

## 类型安全的排序描述符

### 问题

对外属性名改变后，`NSSortDescriptor(keyPath: \Item.date, ascending: true)` 使用的是计算属性，Core Data 无法识别。

### v1 方案：Keys + Paths + 查找表

```swift
struct CDPath<Root, Value> {
    let swiftPath: [String]
    let persistentPath: [String]
}

struct CDFieldMeta {
    let swiftPath: [String]
    let persistentPath: [String]
    let storageMethod: StorageMethod
}

protocol CoreDataKeys {
    associatedtype Keys: RawRepresentable where Keys.RawValue == String
    associatedtype Paths
}

extension Item: CoreDataKeys {
    enum Keys: String {
        case date = "timestamp"   // case 名 = 对外名，rawValue = 持久化字段名
    }

    enum Paths {
        static let date = CDPath<Item, Date?>(
            swiftPath: ["date"],
            persistentPath: ["timestamp"]
        )

        enum magnitude {
            static let richter = CDPath<Item, Double>(
                swiftPath: ["magnitude", "richter"],
                persistentPath: ["magnitude", "richter"]
            )
        }
    }

    // 宏生成：用于 sort /（未来）CDPredicate 的自动映射
    static let __cdFieldTable: [String: CDFieldMeta] = ...
}
```

`enum Keys` 保留用于平面字段；子路径能力通过 `Paths` + `CDPath` 提供（包含 relationship / composition 子路径）。对外调用可提供 `Model.path.*` 作为 `Paths` 的薄封装，减少样板代码。

### NSSortDescriptor 扩展（v1）

通过传入 `Object.Type` 来锚定泛型，让 Swift 能推断 `Object.Keys` / `CDPath`：

```swift
enum SortOrder { case asc, desc }
enum SortCollation {
    case storeDefault
    case localized
    case localizedStandard
}
enum SortExecutionMode {
    case storeCompatible
    case inMemory
}

extension NSSortDescriptor {
    convenience init<Object: NSManagedObject & CoreDataKeys>(
        _ type: Object.Type,
        key: Object.Keys,
        ascending: Bool
    ) {
        self.init(key: key.rawValue, ascending: ascending)
    }

    convenience init<Object: NSManagedObject, Value>(
        _ type: Object.Type,
        path: CDPath<Object, Value>,
        order: SortOrder,
        collation: SortCollation = .storeDefault,
        mode: SortExecutionMode = .storeCompatible
    ) {
        self.init(key: path.persistentPath.joined(separator: "."), ascending: order == .asc)
    }
}

// 使用
NSSortDescriptor(Item.self, key: .date, ascending: true)
NSSortDescriptor(Item.self, path: Item.path.magnitude.richter, order: .desc)
```

说明：`mode` 与 `collation` 用于区分“可下推到 store 的排序”与“需要内存排序的本地化比较”，以支持更多排序构造样式。
补充约束：sort 不支持 to-many 关系路径，遇到时应给出明确错误。

### 谓词中的安全 Key

谓词暂用 `%K` + `Keys.rawValue` 消除裸字符串：

```swift
NSPredicate(format: "%K > %@", Item.Keys.date.rawValue, someDate as CVarArg)
```

### NSPredicate 与 #Predicate

本规范中，查询条件**优先使用 `NSPredicate`**。

`#Predicate` 在以下场景存在能力限制，容易与持久化层真实字段不一致：

- Swift 对外属性名与持久化字段名不一致（`@Attribute(persistentName:)`）
- Swift 类型与持久化存储类型不一致（如 `enum` 对应 `rawValue` 存储）

因此在上述场景中应统一使用 `NSPredicate`（配合 `%K` + `Keys.rawValue`）。

对于 relationship/composition 子路径，建议统一通过路径映射后的 `%K` 构建；to-many 量词语义建议采用：

- `any` -> `ANY %K ...`
- `all` -> `NOT (ANY %K <inverse-op> ...)`
- `none` -> `NOT (ANY %K ...)`

---

## 版本范围

### v1（当前版本）

- 宏 + 校验 + 生成的完整闭环
- `.composition` 存储策略支持
- 类型安全排序的路径能力（`Keys` + `Paths` + 查找表）与比较参数扩展
- 谓词层面以 `NSPredicate` 为规范主路径

### v2（下一阶段）

- 新增 `CDPredicate`：类型安全表达式自动转换为 `NSPredicate`

## 宏设计

### @PersistentModel（类级别宏）

附加在 `NSManagedObject` 子类上，负责：

- 自动分发属性级宏：
  - 普通持久化属性 -> `@Attribute`
  - 关系属性 -> 内部 `@_CDRelationship`
- 收集所有 `@Attribute` 声明，自动生成 `Keys` / `Paths` / `__cdFieldTable`
- 为类添加 `CoreDataKeys` conformance
- 提供关系代码生成策略（to-one getter/setter；to-many getter + helper methods）

```swift
@PersistentModel
final class Item: NSManagedObject, Identifiable {
    @Attribute(persistentName: "timestamp")
    var date: Date?
}

// 宏展开后等价于（示意）：
final class Item: NSManagedObject, Identifiable, CoreDataKeys {
    var date: Date? {
        get { value(forKey: "timestamp") as? Date }
        set { setValue(newValue, forKey: "timestamp") }
    }
    enum Keys: String {
        case date = "timestamp"
    }
}
```

宏类型：`@attached(memberAttribute)` + `@attached(member)` + `@attached(extension)`

> `@objc(ClassName)` 由模型类型显式声明；主宏会在缺失时给出编译期错误。

### @PersistentModel 状态

1. 关系目标类型已在宏展开阶段强约束（`T: PersistentEntity`）。

### 属性级错误策略（decodeFailurePolicy）

v1 将存取失败策略固定在 `@Attribute` 上，通过 `decodeFailurePolicy` 控制。
适用范围：`.raw` / `.codable` / `.transformed`。

```swift
enum AttributeDecodeFailurePolicy {
    case fallbackToDefaultValue   // 默认：回退到属性默认值（可选省略初始化器时视为 nil）
    case debugAssertNil           // Debug assertionFailure，最终返回/写入 nil
}
```

该策略同时作用于：

- getter 的解码/反变换失败
- setter 的编码/变换失败

### @Attribute（属性级别宏）

附加在属性声明上，根据 `storageMethod` 生成对应的 getter/setter。
字段名参数使用 `persistentName:`。
默认值约束：`.default` 与 `.raw` 的非可选持久化属性可省略显式默认值；其他存储策略仍要求可选声明。可选属性可省略初始化器（按 `nil` 处理）。
可选属性省略初始化器时，视为默认 `nil`（无需显式写 `= nil`）。
模型侧同构约束：xcdatamodeld 中若 `.default` / `.raw` attribute 为 `Optional=false`，可以有也可以没有默认值；其他自定义存储首版仍按 optional-only 处理。`Optional=true` 可以不配置默认值。
`decodeFailurePolicy` 仅适用于 `.raw` / `.codable` / `.transformed`，默认 `.fallbackToDefaultValue`，可选 `.debugAssertNil`。
`.raw` 会在编译期约束属性类型满足 `RawRepresentable`，`.codable` 约束为 `Codable`，`.transformed` 要求传入符合 `CDRegisteredValueTransformer` 的元类型（如 `T.self`），`.composition` 约束属性类型满足 `@Composition` 生成协议。

计划中的 trait 扩展：

- `@Attribute(.unique, ...)`

采用 SwiftData 风格的 trait 写法，而不是额外引入 `@Unique` 宏，原因很简单：

1. 避免一个属性同时叠两个宏，降低声明噪音。
2. `unique` 在当前阶段只是 attribute schema 上的一个事实标签，不值得单独做新的宏角色。
3. 对 runtime schema 而言，`unique` 的首版实现可以直接在 metadata 中记为 `Bool`。

首版范围仅限单字段唯一约束；复合唯一约束留到后续实体级 schema 设计时再处理。

默认值职责边界（v1）：

- 代码中的默认值不用于自动落库初始化。
- 属性宏不会生成“属性级 init”去补写持久化字段。
- 主宏生成的 convenience init 也不做“缺省值补写”，只负责参数赋值流程。
- 代码默认值仅用于 fallback（读取/解码/转换失败）与语义表达。
- 持久化默认值的真实来源仍是 xcdatamodeld；一致性由 validate 工具负责检查。

原因：

1. 当前方案以 xcdatamodeld 为模型真值，不是纯代码建模。
2. 若宏在 init 再次补写默认值，会引入与模型默认值重复或冲突的风险。
3. `generateInit` 是可选开关，默认值语义不能绑定在“是否自动生成 init”上。

宏类型：`@attached(accessor)` + `@peer`

---

## StorageMethod：存储策略

```swift
enum StorageMethod {
    case `default`                             // 原生支持类型 + NSNumber 桥接
    case raw                                   // RawRepresentable 枚举
    case codable                               // Codable → Data
    case transformed(CDRegisteredValueTransformer.Type)    // 已注册的 ValueTransformer
    case composition                           // NSCompositeAttributeDescription（v1 支持）
}
```

### .default — 原生类型 + NSNumber 桥接

```swift
@Attribute(persistentName: "timestamp")
var date: Date?
// 展开：
var date: Date? {
    get { value(forKey: "timestamp") as? Date }
    set { setValue(newValue, forKey: "timestamp") }
}

@Attribute(persistentName: "price")
var price: Double?
// 展开（自动 NSNumber 桥接）：
var price: Double? {
    get { (value(forKey: "price") as? NSNumber)?.doubleValue }
    set { setValue(newValue.map { NSNumber(value: $0) }, forKey: "price") }
}
```

宏通过属性的声明类型判断是否需要 NSNumber 桥接（`Int?`、`Double?`、`Float?` 等）。

### .raw — RawRepresentable 枚举

```swift
@Attribute(persistentName: "status", storageMethod: .raw)
var status: Status?   // enum Status: String

// 展开：
var status: Status? {
    get { (value(forKey: "status") as? String).flatMap(Status.init) }
    set { setValue(newValue?.rawValue, forKey: "status") }
}
```

`RawRepresentable` **不会自动推断**，必须显式写 `storageMethod: .raw`。
若属性为非可选且未声明默认值，则读取到缺值或非法 rawValue 时按模型不变量损坏处理并 trap。

### .codable — Codable 序列化为 Data

```swift
@Attribute(persistentName: "metadata", storageMethod: .codable)
var metadata: MyConfig?   // struct MyConfig: Codable

// 展开：
var metadata: MyConfig? {
    get {
        guard let data = value(forKey: "metadata") as? Data else { return nil }
        do {
            return try JSONDecoder().decode(MyConfig.self, from: data)
        } catch {
            // 按 @Attribute(decodeFailurePolicy:) 处理
            return nil
        }
    }
    set {
        do {
            setValue(try JSONEncoder().encode(newValue), forKey: "metadata")
        } catch {
            // 按 @Attribute(decodeFailurePolicy:) 处理
            setValue(nil, forKey: "metadata")
        }
    }
}
```

`Codable` **不会自动推断**，必须显式写 `storageMethod: .codable`。

### .transformed — ValueTransformer

适用于迁移已有 `ValueTransformer` 子类的场景：

```swift
@Attribute(persistentName: "color", storageMethod: .transformed(ColorTransformer.self))
var color: UIColor?

// 展开：
var color: UIColor? {
    get {
        // 失败时按 @Attribute(decodeFailurePolicy:) 处理
        ColorTransformer().reverseTransformedValue(value(forKey: "color")) as? UIColor
    }
    set {
        // 失败时按 @Attribute(decodeFailurePolicy:) 处理
        setValue(newValue.map { ColorTransformer().transformedValue($0) }, forKey: "color")
    }
}
```

注意：schema-backed `.transformed(...)` 字段的模型类型应与 transformer 的持久化输出类型一致。  
例如：

- 输出 `NSString` -> 模型字段应为 `String`
- 输出 `NSData` -> 模型字段应为 `Binary Data`
- 只有显式走安全反序列化路径（如 `NSSecureUnarchiveFromData`）时，模型字段才通常设为 `Transformable`

### .composition — NSCompositeAttributeDescription（v1 支持）

iOS 17+ 专有，仅支持 SQLite store。内存表示为 `[String: Any]?` 字典。

设计思路：配合 `@Composition` 标记的 struct，宏解析 struct 结构自动生成字典的组装/解构代码与静态字段元数据。

```swift
@Composition
struct Magnitude {
    var richter: Double = 0
    var depth: Double = 0
}

@Attribute(persistentName: "magnitude", storageMethod: .composition)
var magnitude: Magnitude?

// 预期展开（v1）：
var magnitude: Magnitude? {
    get {
        guard let dict = value(forKey: "magnitude") as? [String: Any] else { return nil }
        return Magnitude.__cdDecodeComposition(from: dict)
    }
    set {
        setValue(newValue?.__cdEncodeComposition, forKey: "magnitude")
    }
}
```

当 composition leaf 需要不同的底层字段名时，使用独立的 `@CompositionField(persistentName:)`：

```swift
@Composition
struct Location {
    @CompositionField(persistentName: "lat")
    var latitude: Double = 0

    @CompositionField(persistentName: "lng")
    var longitude: Double = 0
}
```

这里的设计目标与 `@Attribute(persistentName:)` / `@Relationship(persistentName:)` 一致：

- Swift-facing 代码继续写 `location.latitude`
- 底层 `__cdCompositionFieldTable` 记录持久化 leaf name（如 `lat`）
- typed path / sort / `%K` predicate 仍从 Swift 路径出发，再映射到持久化路径
- 不复用 `@Attribute`，因为 composition leaf 不是顶层 `NSManagedObject` attribute

`@Composition` 生成成员（命名固定）：

- `static let __cdCompositionFieldTable`
- `static func __cdDecodeComposition(from:) -> Self?`
- `var __cdEncodeComposition: [String: Any]`

解码规则：非可选字段缺失或类型不匹配时返回 `nil`。  
编码规则：可选字段为 `nil` 时不写入字典。

v1 要求：`.composition` 必须可用，不再以“编译期错误占位”延后实现。若运行环境或存储后端不满足条件，工具需给出明确校验错误与迁移提示。

`@Composition` 声明约束（v1）：

- 仅允许 `struct`
- 不允许泛型
- 仅处理实例 `var` 存储属性（不处理 `let`、计算属性、`static`、`lazy`、属性包装器）
- 字段类型仅允许基础类型（含可选）：`String`、`Bool`、`Int`、`Int16`、`Int32`、`Int64`、`Float`、`Double`、`Decimal`、`Date`、`Data`、`UUID`、`URL`
- 不支持转换策略（`.raw` / `.codable` / `.transformed`）
- 字段若需重命名，必须显式使用 `@CompositionField(persistentName: ...)`
- 不支持嵌套 composition
- 必须生成静态元数据供主宏拼接路径/字段表，不依赖反射
- 生成访问权限与原类型保持一致
- 违反约束时报编译期诊断

---

## 自动推断规则（宏实现时参考）

| 属性类型特征 | 默认 storageMethod |
|---|---|
| `String` / `Bool` / `Data` / `Date` / `UUID` / `Int` / `Int16` / `Int32` / `Int64` / `Float` / `Double` / `Decimal`（含可选） | `.default` |
| 其他任意非基础类型 | **不自动推断，必须显式指定**（`.raw` / `.codable` / `.transformed` / `.composition`） |

若非基础类型未显式指定 `storageMethod`，宏在编译期报错。
即使显式写 `storageMethod: .default`，也仅允许上述基础类型（含可选）。
对于 `.default`，非可选属性既可以显式提供默认值，也可以省略默认值作为 required 字段；
后者在读取到底层缺值时应视为模型不变量损坏。

---

## 与 SwiftData @Model 的区别

| | 本方案 | SwiftData @Model |
|---|---|---|
| 模型文件 | 继续使用 xcdatamodeld | 纯代码声明 |
| 运行时 | Core Data | Core Data（底层） |
| 改造程度 | 薄改善层 | 完全替换 |
| 最低版本 | Core Data 支持的所有版本 | iOS 17+ |
| 迁移成本 | 低，渐进式 | 高 |

## 测试 / 调试用 Runtime Schema

这个能力的目标不是“用代码替代 xcdatamodeld”，而是提供一个面向测试与调试的便捷入口：

```swift
let model = NSManagedObjectModel.makeRuntimeModel([
    Item.self,
    Tag.self,
])
```

或等价的 builder 形式。调用方需要显式提供所有相关实体类型，原因是：

- relationship 的目标实体与 inverse 需要在完整集合中解析
- 不做运行时扫描，也不做反射式自动发现

runtime schema 的来源不是手写描述，而是宏生成的静态 metadata。builder 只做组装，不负责推断。

relationship metadata 规则补充：

- 每个 relationship 都必须显式声明 `@Relationship(persistentName:inverse:deleteRule:)`
- 自连接（self relationship）按同一规则处理
- runtime builder 直接消费显式 `inverse`，不再依赖公开的 inverse hint 机制

边界需要保持非常清楚：

- 仅用于测试/调试场景
- 不作为生产持久化模型来源
- 不承诺与 xcdatamodeld 生成出的 model hash 一致
- 不承担迁移和版本管理语义

这套能力的价值在于：

- 非 Xcode 场景可以直接测试 Core Data 代码
- AI 生成或 SPM 环境下不需要先处理 `.xcdatamodeld`
- 可以快速构建临时测试模型，减少集成测试脚手架复杂度

实体继承（deferred）：

- v1 暂不处理 entity inheritance
- inheritance 会同时影响 runtime schema、tooling generate/validate、relationship 目标解析与 metadata 继承规则
- 该主题应在后续版本单独设计

而它之所以可行，是因为本方案已经对模型声明施加了足够多的约束，消除了很多“代码无法稳定反推模型”的情况。
---

## 配套工具：模型校验与代码生成

### 定位

独立的开发期工具，不参与运行时。以 **SPM Plugin** 为主要形态，也可提供独立 CLI。

核心功能两个：
1. **校验**：检查 Swift 代码声明与 xcdatamodeld 定义是否匹配
2. **生成**：从 xcdatamodeld 直接生成初始 Swift 代码，供开发者修改

---

### 功能一：校验（Validate）

解析 xcdatamodeld（本质是 XML）和 Swift 源码中的 `@Attribute` 声明，逐项对比。

**检查项**：

| 检查项 | 说明 |
|---|---|
| Codegen 模式 | 每个 Entity 的 Codegen 必须为 Manual/None（硬性要求） |
| 持久化字段名 | `@Attribute(persistentName:)` 中的名称是否在模型中存在 |
| 类型兼容性 | Swift 类型与 Core Data attribute type 是否匹配（含 NSNumber 桥接规则）|
| Attribute Optional 一致性 | Swift 侧 attribute 是否可选与模型中 Optional 勾选是否一致 |
| Default value | 模型中设置的默认值与 Swift 侧初始值是否匹配 |
| 模型默认值硬约束 | 模型中 `Optional=false` 的 attribute 是否提供默认值 |
| StorageMethod 合理性 | 比如对 `.raw` 检查 rawValue 类型与字段类型是否一致 |
| 孤立字段 | 模型中存在但 Swift 中没有任何 `@Attribute` 对应的字段（可能遗漏）|
| 孤立声明 | Swift 中的 `@Attribute` 在模型中找不到对应字段 |
| 关系名一致性 | Swift 侧关系属性名与 xcdatamodeld 当前版本关系名是否一致 |
| 关系可选性（代码层） | Swift 侧对多是否为非可选、对一是否为可选 |
| 关系 Optional（模型层） | xcdatamodeld 中对多关系是否为 Optional=true（硬性要求） |
| 关系 inverse（模型层） | xcdatamodeld 中每条 relationship 都必须配置 inverse（硬性要求） |
| `@Relationship(...)` 一致性 | 校验 `inverse`、`deleteRule` 与 ordered/unordered 是否和模型一致 |
| Undefined 类型 | 模型中存在 Undefined 类型的属性，宏不支持，需要开发者处理 |

**最佳实践建议（`[SUGGEST]`）**：

工具除校验错误外，还会分析模型结构并给出建议，帮助开发者提前规避潜在问题：

| 建议场景 | 说明 |
|---|---|
| 不符合 CloudKit 标准 | 如存在非可选属性无默认值、有序关系（CloudKit 不支持 `NSOrderedSet`）等 |
| 使用 Undefined 类型 | 该属性无法被宏处理，需要开发者手动实现或改用其他类型 |

**输出示例**：

```
[ERROR]   Item: codegen must be Manual/None, found "Class Definition"
[MIGRATION] Open xcdatamodeld -> Item -> Codegen, set to Manual/None, then rerun validation
[ERROR]   Item.date: persistent key "timestamp" not found in entity "Item"
[ERROR]   Item.price: type mismatch — model has Integer16, Swift declares Double?
[ERROR]   Item.rating: attribute type is Undefined, not supported by @Attribute macro
[ERROR]   Item.tags: to-many relationship must be Optional in xcdatamodeld (required by this convention)
[ERROR]   Item.tags: relationship has no inverse set (required by this convention)
[MIGRATION] Open xcdatamodeld -> Item.tags, set Inverse to Tag.items (or matching inverse relationship), then rerun validation
[WARN]    Item.count: model field is non-optional, but Swift declares Int? (optional)
[WARN]    Item.note: model sets default value "untitled", Swift side has no matching default
[SUGGEST] Item.tags: ordered relationship is incompatible with CloudKit sync
[SUGGEST] Item.title: non-optional attribute has no default value — incompatible with CloudKit
[INFO]    Item.createdAt: model field exists but no @Attribute declaration found
```

---

### 功能二：代码生成（Generate）

读取 xcdatamodeld，为每个 Entity 生成初始 Swift 文件，作为**开发起点**，开发者在此基础上修改属性名、调整 storageMethod。

**生成前置约束（硬性）**：

- 若任一 Entity 的 Codegen 不是 Manual/None，生成器必须直接拒绝生成
- 若模型中任一 relationship 缺少 inverse，生成器必须直接拒绝生成
- 若模型中任一 to-many relationship 为 `Optional=false`，生成器必须直接拒绝生成
- 诊断输出需与校验器一致，包含 `[ERROR]` 和可执行的 `[MIGRATION]` 提示

```text
[ERROR]   Item: codegen must be Manual/None, found "Class Definition"
[MIGRATION] Open xcdatamodeld -> Item -> Codegen, set to Manual/None, then rerun generation
[ERROR]   Item.tags: relationship has no inverse set (required by this convention)
[MIGRATION] Open xcdatamodeld -> Item.tags, set Inverse to Tag.items (or matching inverse relationship), then rerun generation
[ERROR]   Item.tags: to-many relationship must be Optional in xcdatamodeld (required by this convention)
[MIGRATION] Open xcdatamodeld -> Item.tags, set Optional=true, then rerun generation
```

**生成示例**

给定模型中 `Item` 实体有字段：`timestamp(Date)`, `price(Double)`, `status(String)`, `count(Int16)`

生成：

```swift
@PersistentModel
final class Item: NSManagedObject, Identifiable {

    // TODO: rename if needed. persistent key: "timestamp"
    @Attribute(persistentName: "timestamp")
    var timestamp: Date?

    // TODO: rename if needed. persistent key: "price"
    @Attribute(persistentName: "price")
    var price: Double?

    // TODO: rename if needed. persistent key: "status"
    // NOTE: consider .raw if this maps to an enum
    @Attribute(persistentName: "status")
    var status: String?

    // TODO: rename if needed. persistent key: "count"
    @Attribute(persistentName: "count")
    var count: Int?
}
```

生成的代码本身即可通过校验，开发者只需按需重命名对外属性名。

---

### 工具形态

**SPM Build Tool Plugin（推荐）**

集成到构建流程，校验失败时作为编译警告或错误输出，无需额外命令：

```swift
// Package.swift
.plugin(name: "CoreDataModelValidate", capability: .buildTool())
```

**SPM Command Plugin**

按需手动触发，适合代码生成场景：

```bash
swift package generate-coredata-model --entity Item
swift package validate-coredata-model
```

**独立 CLI（次要）**

适合 CI 集成或不使用 SPM 的项目：

```bash
coredata-tool validate --model Model.xcdatamodeld --source Sources/
coredata-tool generate --model Model.xcdatamodeld --output Sources/Models/
```

---

### 实现要点

- **xcdatamodeld 解析**：本质是 XML，用 `Foundation` 的 `XMLParser` 或直接解析 `.xcdatamodel/contents` 文件即可，不需要依赖 Core Data 框架
- **Swift 源码解析**：使用 **SwiftSyntax** 读取 `@Attribute` 宏的参数和属性类型声明
- **类型映射表**：维护一张 Core Data attribute type → Swift 类型的映射，处理 NSNumber 桥接等边界情况
- **Build Tool Plugin 限制**：只能读文件、输出诊断，不能修改源码，因此生成功能需要作为 Command Plugin 单独提供
