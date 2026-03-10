# CoreData Macro System Specification

## 1. Scope

本规范定义 v1 与 v2 边界、宏行为、工具校验规则与诊断输出约束。

### v1

- 宏：`@PersistentModel` `@Attribute` `@Ignore` `@Composition`
- 存储策略：`.default` `.raw` `.codable` `.transformed` `.composition`
- 排序能力：`Keys + Paths + __cdFieldTable`
- 查询规范：优先 `NSPredicate`
- 工具：`validate` + `generate`

### v2

- `CDPredicate`

### Planned (Test / Debug Only)

- Runtime Schema Metadata
- 纯代码 `NSManagedObjectModel` 构建辅助

Runtime schema / runtime model builder 的 v1 边界：

- 仅用于测试/调试，不替代 `xcdatamodeld`
- 假定宏生成的静态 metadata 为唯一输入，不做运行时反射
- 同一组模型类型应复用缓存后的 `NSManagedObjectModel`
- 关系元数据最终以 `@Relationship(persistentName:inverse:deleteRule:)` 为源码真值，不依赖 inverse 推断
- primitive 默认值仅支持可稳定翻译到 Core Data 默认值的表达式子集；不支持时直接报错
- composition 在 runtime 路径中按单个 transformable dictionary payload 建模，不追求与 xcdatamodeld 的展平字段布局一致
- 纯代码模型当前不支持声明以下低优先级模型元数据：
  - `allowsExternalBinaryDataStorage`
  - `spotlight`
  - `preserveValueOnDeletion`
  - `valueRange`
- `dateRange`
- 这些限制只作用于 runtime schema / pure-code model 路径，不影响正常的 `xcdatamodeld` 工作流
- tooling 现在提供 `compositionRules` 配置模型，用于记录 composition leaf 的
  `persistentName -> swiftName` 映射；当前这组规则进入 inspect/build IR，并为后续源码生成与
  校验保留统一输入形态

## 2. Hard Rules

1. `xcdatamodeld` 每个 Entity 的 Codegen 必须为 `Manual/None`。
2. 模型层每条 relationship 必须配置 inverse。
3. 模型层 to-many relationship 必须 `Optional=true`。
4. 代码层 to-many 必须非可选（`Set<T>` / `[T]`）。
5. 代码层 to-one 必须可选（`T?`）。
6. 构造方法不接收任何关系参数；关系只能在双方对象创建并 `insert` 后显式建立。
7. 有序 to-many (`[T]`) 永不生成 setter。
8. `@Ignore` 仅用于 `var`；`let` 默认忽略。
9. 关系属性名必须与 xcdatamodeld 中的关系名保持一致，不支持重命名映射。
10. 模型层 attribute 必须满足“可选或有默认值”：若 `Optional=false`，则必须在 xcdatamodeld 中提供默认值。
11. 代码层持久化属性必须满足同构规则：若为非可选必须显式默认值；若为可选可省略初始化器（视为默认 `nil`，无需写 `= nil`）。
12. 不支持 Derived Attribute（派生属性）；模型检查发现 derived attribute 时，`validate` 直接报错，`generate` 直接拒绝。

## 3. Macro Behavior

### `@PersistentModel`

必须生成：

- `CoreDataKeys` conformance
- 对未标注 `@Attribute` 的持久化 attribute 属性自动附加 `@Attribute`（`@Ignore` / relationship 除外）
- `Keys`（平面 key）
- `Paths`（可组合子路径，含 relationship/composition）
- `__cdFieldTable`（路径映射元信息）
- `convenience init`（默认不生成；可通过 `generateInit: true` 开启）

`@objc` 注入规则：

- v1 要求模型类型显式声明 `@objc(ClassName)`（或 `@_objcRuntimeName(...)`）。
- 若缺失，`@PersistentModel` 会给出编译期错误并拒绝展开。
- 说明：当前 Swift 宏角色不支持自动改写宿主类型属性，因此不做“自动注入”。

访问权限继承规则：

- 宏生成的所有代码（计算属性、便利方法、`Keys`、`Paths`、`__cdFieldTable`、构造方法）严格继承类型本身的访问权限，不自动提升或降低。

```swift
@PersistentModel(
  generateInit: false,
)
```

当前策略语义：

- 对多 getter（`Set<T>` / `[T]`）当前固定生成，不提供单独策略开关。
- 不生成任何 `*Count` 访问器，推荐改用 `NSManagedObjectContext.count(for:)` + `NSPredicate`。
- `Set<T>` 仅生成 `add/remove` 便利方法，不生成批量替换 helper。

### `@Attribute`

- 参数：`persistentName`（映射持久化字段名），`storageMethod`，`decodeFailurePolicy`。  
- `persistentName` 的语义与 SwiftData 的 `originalName` 不同：
  - `persistentName` 表示“当前 Swift 属性对应的持久化字段名”
  - 不表示“旧 schema 中的历史属性名”
- 持久化属性必须有默认值：非可选属性需显式默认值；可选属性可省略初始化器（视为默认 `nil`）。  
- 上述代码规则必须与模型层规则一致：模型中非可选 attribute 必须配置默认值；可选 attribute 可以不配置默认值。  
- 对基础类型自动 `.default`。  
- 非基础类型必须显式 `storageMethod`。  
- 支持 `.raw` `.codable` `.transformed` `.composition`。  
- `storageMethod: .default`（显式或隐式）仅允许基础类型（含可选）：
  `String`、`Bool`、`Int`、`Int16`、`Int32`、`Int64`、`Float`、`Double`、`Decimal`、`Date`、`Data`、`UUID`、`URL`。
- `decodeFailurePolicy` 仅适用于 `.raw` / `.codable` / `.transformed`：
  - `.fallbackToDefaultValue`（默认）
  - `.debugAssertNil`
- 代码中的默认值**不用于自动落库初始化**（不会在属性级或主宏生成的 init 中额外写入持久化字段）。
- 代码默认值在 v1 仅承担两类职责：
  - 读取/解码/转换失败时的 fallback 值
  - 作为属性语义与意图的显式声明
- 持久化层默认值的真实来源是 xcdatamodeld；工具需校验“模型默认值 vs 代码默认值”一致性。
- `.raw` 会在编译期约束属性类型满足 `RawRepresentable`。
- `.codable` 会在编译期约束属性类型满足 `Codable`。
- `.transformed` 要求传入符合 `CDRegisteredValueTransformer` 的元类型（如 `MyTransformer.self`）。
- schema-backed `.transformed(...)` 字段的模型类型应与 transformer 的持久化输出类型一致：
  - 输出 `NSString` -> `String`
  - 输出 `NSData` -> `Binary Data`
  - 只有显式走安全反序列化路径（如 `NSSecureUnarchiveFromData`）时，模型字段才通常设为 `Transformable`
- `.composition` 会在编译期约束属性类型满足 `@Composition` 生成的协议能力（`CDCompositionPathProviding` + `CDCompositionValueCodable`）。
- `@Attribute` 不能标注关系属性（`T?` / `Set<T>` / `[T]` 且 `T: NSManagedObject`）；关系由主宏按类型自动识别并生成代码。
- `decodeFailurePolicy` 同时用于 getter 解码失败与 setter 编码/转换失败。
- trait 语法：
  - `@Attribute(.unique, ...)`
  - `@Attribute(.transient, ...)`
- `unique` 首版按单一 trait 处理，不新增单独宏：
  - 宏内部 metadata 可直接记录为 `Bool`
  - 仅用于测试/调试用 runtime schema 的 uniqueness constraint 组装
  - 不改变现有 getter/setter 生成逻辑
  - 首版只支持单字段 unique，不支持复合唯一约束
- `transient` 首版同样按单一 trait 处理，不新增单独宏：
  - 表示该 attribute 仍属于 Core Data 模型，但 `isTransient = true`
  - 不等同于 `@Ignore`；`@Ignore` 仍表示“完全不进入 Core Data 模型”的纯内存属性
  - v1 仅允许与 `.default` 存储配合使用
  - v1 禁止与 `.raw` / `.codable` / `.transformed` / `.composition` 混用
  - tooling 的 `generate` / `validate` 需要识别并校验该 trait
- 不支持派生属性（Derived Attribute）：
  - v1 不为 derived attribute 生成代码
  - v1 不提供与派生表达式对齐的 DSL 或 metadata
  - 模型检查发现 derived attribute 时，`validate` 直接报错，`generate` 直接拒绝

### `@Ignore`

- 被标记的 `var` 不参与持久化代码生成。  
- `let` 无需标记，默认不参与持久化生成。  

### `@Relationship`

- 仅用于 relationship 属性。
- 语法：`@Relationship(persistentName: nil, inverse: "property", deleteRule: .nullify, minimumModelCount: nil, maximumModelCount: nil)`
- `persistentName` 为可选参数，表示当前 Swift relationship 对应的持久化关系名。
- `inverse` 必填。
- `deleteRule` 必填。
- `minimumModelCount` / `maximumModelCount` 为可选参数：
  - 对 to-many relationship，Core Data 中 `maxCount == 0` 表示“无上限”，不是“最多 0 个”
  - 仅在模型声明了非默认关系计数约束时才需要出现在源码中
  - 默认关系界限由 Core Data relationship 形态决定（例如可选 to-one 为 `0...1`）
- relationship 属性本身已经提供目标实体类型，因此 `@Relationship` 只需要补充当前关系的持久化名、对端持久化关系名与删除策略。
- `inverse` 指向的是对端 relationship 在 Core Data 模型中的名字，不是对端 Swift 属性名。
- `deleteRule` 仅支持：`.nullify`、`.cascade`、`.deny`。
- `.noAction` 在 v1 中明确不支持；tooling 读取到模型里的 `No Action` delete rule 时会直接报错。
- 不再依赖公开的 `@Inverse` 或结构化关系注释。

### `@Composition`

- 标记 struct 以支持 `.composition` 存储策略。
- 术语说明：CoreDataEvolution 在源码层使用 `composition`，对应 Core Data 模型层的
  `composite attribute`。
- 宏解析 struct 成员，自动生成 `[String: Any]` 字典的组装/解构代码与字段表元数据。
- v1 生成成员（命名固定）：
  - `static let __cdCompositionFieldTable`
  - `static func __cdDecodeComposition(from:) -> Self?`
  - `var __cdEncodeComposition: [String: Any]`
- 解构规则：非可选字段缺失或类型不匹配时返回 `nil`。
- 组装规则：可选字段为 `nil` 时不写入字典。
- 仅支持 iOS 17+ / SQLite store。

### `@CompositionField`

- 仅用于 `@Composition` struct 内的字段。
- 语法：`@CompositionField(persistentName: "lat")`
- `persistentName` 表示当前 composition leaf 在 Core Data 模型中的持久化字段名。
- Swift-facing 字段名保持不变；typed path 仍从 Swift 路径出发，再映射到持久化路径。
- 不复用 `@Attribute`，因为 composition leaf 不是顶层 `NSManagedObject` attribute 声明。

v1 声明约束（硬性）：

1. 仅允许标注在 `struct` 上（不支持 class/actor/enum/protocol）。
2. 不允许泛型 composition 类型（例如 `struct Box<T>`）。
3. 仅处理实例 `var` 存储属性；不处理 `let`、计算属性、`static`、`lazy`、属性包装器。
4. 字段类型仅允许基础类型（含可选）：`String`、`Bool`、`Int`、`Int16`、`Int32`、`Int64`、`Float`、`Double`、`Decimal`、`Date`、`Data`、`UUID`、`URL`。
5. composition 内字段不支持转换策略（不支持 `.raw` / `.codable` / `.transformed`）。
6. composition 内字段若需重命名，必须显式使用 `@CompositionField(persistentName: ...)`。
7. 不支持嵌套 composition。
8. 必须生成静态元数据（如 composition 字段表），供主宏拼接 `__cdFieldTable`，不依赖反射。
9. 生成成员访问权限与原类型访问权限保持一致。
10. 违反以上任一约束时，宏必须给出编译期诊断错误。

## 4. Relationship Semantics

### 类型到关系识别

- `Set<T>` -> 无序 to-many  
- `[T]` -> 有序 to-many  
- `T?` -> to-one  

> 说明：关系目标类型在宏展开代码中通过 `_CDRelationshipMacroValidation.requirePersistentEntity(T.self)` 做编译期强约束。

relationship declaration 规则：

- 每个 relationship 属性都必须显式声明 `@Relationship(...)`
- `persistentName` 若存在，表示当前 relationship 在模型中的名字
- `inverse` 必须写出对端 relationship 在模型中的持久化关系名
- `deleteRule` 必须显式写出，不做源码层推断
- 自连接按同一规则处理
- 缺少 `@Relationship(...)` 时，主宏应在编译期报错并拒绝展开

### Getter / Setter

- `[T]` getter 固定生成，setter 永不生成。  
- `T?` 生成 getter/setter。  

### Count

- 当前不自动生成 `*Count`。  

## 5. Constructor Contract

构造方法规则：

- 包含所有非关系的实例存储属性参数（含 `@Ignore`），不包含 relationship 参数。  
- 生成参数不带默认值，要求调用方显式传入。  
- 不接收 `context`。  
- 内部使用：`self.init(entity: Self.entity(), insertInto: nil)`。  
- 不负责“默认值落库”补写；是否有持久化默认值由模型层（xcdatamodeld）决定。  

原因（约束说明）：

1. 本方案不是纯代码建模，模型层默认值是底层真值来源。  
2. 若宏在 init 中再补写默认值，可能与模型默认值重复或冲突。  
3. `generateInit` 是可选能力，默认值语义不应依赖它是否开启。  

调用方规则：

1. 创建对象。  
2. 显式 `context.insert(...)`。  
3. 对双方都已插入的对象建立关系。  

## 6. Sort Contract (v1 Must)

必须支持两类构造：

1. 平面 key 构造：`NSSortDescriptor(Item.self, key: .date, ascending: true)`  
2. 子路径构造：`NSSortDescriptor(Item.self, path: Item.path.magnitude.richter, order: .desc)`  

支持参数：

- `order`
- `collation`
- `mode`（区分 storeCompatible / inMemory）

约束：

- sort 不支持 to-many 关系路径；遇到 to-many 路径需给出明确错误。  

## 7. Predicate Contract

查询条件优先使用 `NSPredicate`。

推荐通过 `%K` + 路径映射构建：

- 平面字段：`Item.Keys.xxx.rawValue`
- 路径字段：`Item.path.xxx.raw`（或等价映射结果）

`#Predicate` 在下列场景不作为规范路径：

- 对外名与持久化名不一致（`@Attribute(persistentName:)`）
- Swift 类型与持久化类型不一致（例如 enum/rawValue）

推荐写法：

```swift
NSPredicate(format: "%K == %@", Item.Keys.status.rawValue, status.rawValue)
```

关系量词建议：

- `any` -> `ANY %K ...`
- `all` -> `NOT (ANY %K <inverse-op> ...)`
- `none` -> `NOT (ANY %K ...)`

## 9. Current Execution Plan (Main Macro)

以下是当前 `@PersistentModel` 的实现顺序（与代码/测试同步）：

1. **Build unblock**：TypedPath 关系辅助类型可编译。  
   验证：`swift build`
2. **Doc align**：统一参数与策略说明（无 `relationshipGetterPolicy`）。  
   验证：文档自检 + `rg "relationshipGetterPolicy"`
   验证：`swift test --filter MacroDiagnosticTests` + `swift test --filter MacroExpansionSnapshotTests`
4. **Snapshot baseline**：补齐 `PersistentModelBasic` 快照。  
   验证：`UPDATE_SNAPSHOTS=1 swift test --filter MacroExpansionSnapshotTests` 后再次无更新模式运行
5. **Incremental features**：按 “参数 -> 展开成员 -> 关系 helper” 逐项补充测试再实现。  
   验证：每项至少一条诊断测试或快照测试

## 10. PersistentModel Closure

此前挂起的三项能力已闭环：

1. `@objc` 规则：改为“显式声明强校验”（非自动注入）。
2. 关系目标类型：宏展开阶段已强制 `T: PersistentEntity`。

## 11. Runtime Schema For Tests / Debugging (Planned)

目标：

- 为测试、调试、SPM/CLI 非 Xcode 场景提供“纯代码构建 `NSManagedObjectModel`”能力
- 复用 `@PersistentModel` / `@Attribute` / `@Composition` / `@CompositionField` 已声明的信息
- 避免测试场景依赖 `.xcdatamodeld` / `.momd`

非目标：

- 不替代 `xcdatamodeld`
- 不用于生产持久化模型
- 不保证与 `xcdatamodeld` 的 hash / version / migration 行为一致
- 不处理历史版本迁移

设计约束：

1. 不依赖运行时反射；仅消费宏生成的静态 schema metadata。
2. 调用方必须显式提供所有相关实体类型，例如 `makeRuntimeModel([Item.self, Tag.self])`。
3. relationship 解析要求目标类型与 inverse 两端都在输入集合中。
4. relationship 需要源码通过 `@Relationship(persistentName:inverse:deleteRule:)` 提供显式 metadata；不依赖 inverse 推断。
5. composition 仍按已生成的字段表展开为底层 attribute 集合。
6. 由于当前范式已强约束“attribute 必须可选或有默认值、relationship 必须 optional 且有 inverse”，这些信息足以用于测试模型构建。

`@Attribute(.unique)` / `@Attribute(.transient)` 约定：

- 采用 SwiftData 风格 trait 写法，而非新增 `@Unique` 宏。
- 首版仅表示“该字段参与单字段唯一约束”。
- 宏展开后的 runtime metadata 中记录为简单布尔值即可。
- 后续若需要复合唯一约束，再单独设计实体级 schema 能力，不在此阶段引入。
- `transient` 也采用同一 trait 语法：
  - `@Attribute(.transient, persistentName: "cached_summary")`
  - 表达的是 Core Data transient attribute，而不是模型外属性
  - v1 仍按 `.default` 存储处理，禁止与其它 storageMethod 混用

预期 API 方向：

```swift
let model = NSManagedObjectModel.makeRuntimeModel([
  Item.self,
  Tag.self,
])
```

或等价的 builder 入口；命名可在实现阶段再收敛。

实体继承（deferred）：

- v1 暂不处理 entity inheritance。
- inheritance 会影响 runtime schema、tooling generate/validate、relationship 目标解析与 metadata 继承规则。
- 该议题延期到后续版本单独收敛。

## 8. Tool Contract

### Validate

必须检查：

- Codegen = `Manual/None`
- Derived Attribute = unsupported（发现即 error）
- Attribute 映射/类型/optional/default/storageMethod
- 持久化属性默认值约束（非可选必须显式默认值；可选省略初始化器按 `nil` 处理）
- 模型层默认值约束（`Optional=false` 的 attribute 必须有默认值；`Optional=true` 可无默认值）
- relationship 命名与可选性（代码层）
- 模型层 to-many optional
- 模型层 inverse
- `@Relationship(...)` 一致性，含 `inverse` / `deleteRule` 与属性类型的自洽性
- 孤立字段（模型中存在但 Swift 中无对应 `@Attribute`）
- 孤立声明（Swift 中的 `@Attribute` 在模型中无对应字段）
- Undefined 类型属性（宏不支持，需开发者处理）

建议级别（`[SUGGEST]`）：

- CloudKit 兼容性（非可选属性无默认值、有序关系等）
- Undefined 类型提示

### Generate

生成前必须拒绝以下情况：

- Codegen 非 `Manual/None`
- 存在 Derived Attribute
- 任一 relationship 缺 inverse
- 任一 to-many relationship `Optional=false`

## 9. Diagnostics Contract

诊断等级：

- `ERROR`：阻塞构建/生成
- `WARN`：非阻塞风险
- `SUGGEST`：最佳实践建议
- `INFO`：信息提示
- `MIGRATION`：可执行迁移步骤

示例：

```text
[ERROR]   Item: codegen must be Manual/None, found "Class Definition"
[MIGRATION] Open xcdatamodeld -> Item -> Codegen, set to Manual/None, then rerun validation
[ERROR]   Item.tags: relationship has no inverse set (required by this convention)
[MIGRATION] Open xcdatamodeld -> Item.tags, set Inverse to Tag.items (or matching inverse relationship), then rerun validation
```
