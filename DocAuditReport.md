# Docs 审核报告

审核范围：`Docs/` 根目录下的对外文档（`NSModelActorGuide.md`、`PersistentModelGuide.md`、`StorageMethodGuide.md`、`TypedPathGuide.md`、`CDEToolGuide.md`）。

审核方式：逐一比对文档中的 API 用法、参数签名、生成成员列表、CLI 标志类型等与实际代码实现。

---

## 复核结论

2026-03-10 复核结果：

- 报告中的 6 条问题均成立。
- 问题二的影响范围比原报告更大：除 `PathRoot` 和条件生成的 `fetchRequest()` 外，宏还会生成 relationship target validation helpers（`__cd_relationship_validate_*`）。
- 问题六的影响范围也更大：`init-config` 除 `--preset` 外，还支持文档未提及的 `--force`。

---

## 发现的问题

### 问题一：`NSModelActorGuide.md` — `makeRuntimeTest` 缺少参数标签

**位置**：第 257 行

**文档内容**：

```swift
let container = try NSPersistentContainer.makeRuntimeTest(Item.self, Tag.self)
```

**实际 API**（`NSPersistentContainer+Testing.swift:154-168`）：

```swift
public static func makeRuntimeTest(
  modelTypes: any CDRuntimeSchemaProviding.Type...,
  ...
) throws -> NSPersistentContainer
```

**问题**：Swift 可变参数调用中，首个实参仍需提供参数标签 `modelTypes:`。不带标签的写法会编译失败。

**正确写法**：

```swift
let container = try NSPersistentContainer.makeRuntimeTest(modelTypes: Item.self, Tag.self)
```

**对比**：同文件（`PersistentModelGuide.md:775-777`）中使用 `makeRuntimeTest(modelTypes: Item.self, Tag.self)` 写法是正确的。

---

### 问题二：`PersistentModelGuide.md` — 生成成员列表不完整

**位置**：第 83–96 行（"What `@PersistentModel` Generates"）

**文档列出的成员**：

- `Keys`
- `Paths`
- `path`
- `__cdFieldTable`
- `__cdRelationshipProjectionTable`
- `__cdRuntimeEntitySchema`
- 可选 `init(...)`
- to-many add/remove helpers
- `PersistentEntity` 协议遵循
- `CDRuntimeSchemaProviding` 协议遵循

**实际代码**（`PersistentModelMacro.swift:151-210`）还会生成：

1. **`PathRoot`**：由 `makePathRootDecl`（第 159-165 行）生成，是 path DSL 的根类型。
2. **`fetchRequest()`**：由 `makeFetchRequestDecl`（第 195-203 行）生成，仅在类型自身未声明 `fetchRequest()` 时才合成。
3. **relationship target validation helpers**：由 `makeRelationshipTargetValidationDecls`（关系属性各生成一个 `__cd_relationship_validate_*` 成员）生成。

这些生成成员在文档的生成列表中缺失。

---

### 问题三：`PersistentModelGuide.md` — "Recommended Style" 示例缺少 `@PersistentModel`

**位置**：第 958–961 行

**文档内容**：

```swift
@objc(Item)
final class Item: NSManagedObject {
```

**问题**：`@PersistentModel` 注解被遗漏了。同一示例中 `Tag` 类（第 983 行）正确地标注了 `@PersistentModel`，而 `Item` 类没有。按照文档自身所规定的规则，缺少该注解的声明不会触发任何宏展开。

**正确写法**：

```swift
@objc(Item)
@PersistentModel
final class Item: NSManagedObject {
```

---

### 问题四：`CDEToolGuide.md` — `inspect --config` 示例缺少必填的 `--model-path`

**位置**：第 467–469 行

**文档内容**：

```bash
cde-tool inspect --config cde-tool.json
```

**实际 CLI 定义**（`InspectCommand.swift:27-29`）：

```swift
@Option(name: .long, help: "Path to source model ...")
var modelPath: String
```

**问题**：`modelPath` 类型为非可选的 `String`，且没有默认值。根据 Swift ArgumentParser 的规则，这是一个**必填选项**。不提供 `--model-path` 时，命令会在 `run()` 执行前报错退出。

**正确写法**：

```bash
cde-tool inspect \
  --model-path Models/AppModel.xcdatamodeld \
  --config cde-tool.json
```

---

### 问题五：`CDEToolGuide.md` — `generate` 的 `--dry-run` 被错误描述为 flag

**位置**：第 336–338 行（"Useful flags" 列表）

**文档内容**：

```
- `--dry-run`
  - show planned writes without touching disk
```

**实际 CLI 定义**（`GenerateCommand.swift:57`）：

```swift
@Option(name: .long, help: "Whether to preview changes without writing files (true/false).")
var dryRun: Bool?
```

**问题**：`generate` 的 `dryRun` 是 `@Option`（需要传值），正确用法为 `--dry-run true`，而不是独立的 flag `--dry-run`。文档的写法令用户误以为与 `validate` 的 `--dry-run`（后者确实是 `@Flag`）行为一致。

**对比**：
- `validate` 中（`ValidateCommand.swift:94-98`）：`@Flag var dryRun = false` → 用法为 `--dry-run` ✓
- `generate` 中（`GenerateCommand.swift:57`）：`@Option var dryRun: Bool?` → 用法应为 `--dry-run true`

---

### 问题六：`CDEToolGuide.md` — `init-config` 未完整文档化的选项

**位置**：第 535–545 行（"`init-config`" 小节）

**文档内容**：仅提及 `--output` 和 `--stdout`，未提及 `--preset` 与 `--force`。

**实际 CLI 定义**（`InitConfigCommand.swift:32-34`）：

```swift
@Option(name: .long, help: "Template preset: minimal/full.")
var preset: Preset = .full
```

并且：

```swift
@Flag(name: .long, help: "Overwrite existing config file.")
var force = false
```

**问题**：`init-config` 支持 `--preset minimal` 和 `--preset full`（默认为 `full`），用于控制生成的模板详细程度；同时支持 `--force` 覆盖已存在的配置文件。文档中没有提及这些选项，导致用户无法发现该功能。

---

## 无问题项（已核实）

以下内容经过代码比对，与实际实现一致，无需修改：

- `@NSModelActor` 生成 `nonisolated let modelExecutor` 和 `nonisolated let modelContainer`，与文档描述匹配。
- `@NSMainModelActor` 生成非 `nonisolated` 的 `let modelContainer`，`modelContext` 通过协议扩展计算得到，与文档描述匹配。
- `withContext` 的两个重载（单参数和双参数）在两个协议中均有实现，与文档描述一致。
- `disableGenerateInit` 参数在两个宏中均通过 `shouldGenerateInitializer(from:)` 解析，逻辑正确。
- `NSMainModelActor` 协议本身标注了 `@MainActor`（`NSMainModelActor.swift:18`），文档中"需要在类上标注 `@MainActor`"的说明属于源码层要求，描述准确。
- `StorageMethodGuide.md` 和 `TypedPathGuide.md` 中的 API 描述与 `Macros.swift` 中的枚举定义及协议要求一致。
- `makeRuntimeModel` 使用 `_`（无标签）的可变参数重载，文档中 `makeRuntimeModel(Item.self, Tag.self)` 的写法是正确的。
- `bootstrap-config` 的 `--style` 选项（对应代码中的 `--style`/`ToolingBootstrapConfigStyle`）与文档中 `--style explicit` 的描述一致。
