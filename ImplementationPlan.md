# CoreData Macro System Implementation Plan

## 1. Goal

在保留 `xcdatamodeld` 工作流前提下，落地一套可执行的 Core Data 开发范式：

- 宏生成：属性访问、关系访问、排序 key/path 元信息
- 工具能力：`validate` + `generate`
- 强约束：Codegen / inverse / to-many optional 等规范落地

## 2. Version Scope

### v1 (Must)

- `@PersistentModel` / `@Attribute` / `@Ignore` / `@Composition`
- `StorageMethod`: `.default` `.raw` `.codable` `.transformed` `.composition`
- 类型安全排序：`Keys + Paths + __cdFieldTable`
- 查询规范：优先 `NSPredicate`（`%K + key/path 映射`）
- 工具：`validate` 与 `generate` 的硬性校验与迁移提示

### v2 (Next)

- `CDPredicate`：类型安全表达式自动转换到 `NSPredicate`
- Runtime Schema Metadata（测试 / 调试用）
- 纯代码 `NSManagedObjectModel` 构建辅助

## 3. Milestones

### M1: Macro Skeleton + Hard Constraints

- 完成 `@PersistentModel` 基本展开（`@objc` 规则校验、`CoreDataKeys` conformance、访问权限继承）
- 完成 `@PersistentModel` 参数：`generateInit`、`relationshipSetterPolicy`、`relationshipCountPolicy`
- 完成 `@Attribute` 的 `.default/.raw/.codable/.transformed/.composition` 展开，以及 `.unique/.transient` trait 语义
- 完成 `@Composition` 宏：解析 struct 成员，生成 `[String: Any]` 字典组装/解构代码（`__cdDecodeComposition` / `__cdEncodeComposition`）
- 落实 `@Composition` v1 约束：
  - 仅允许 struct、禁止泛型
  - 仅实例 `var` 存储属性
  - 字段类型仅基础类型（含可选，含 `URL`）
  - 不支持转换、不支持重命名、不支持嵌套
  - 生成静态元数据供主宏使用
  - 访问权限继承 + 违规时报编译期诊断
- 完成 `@Ignore` 行为：仅对 `var` 生效，`let` 默认忽略
- 完成关系规则：
  - 代码层：to-many 非可选，to-one 可选
  - 关系属性名必须与 xcdatamodeld 一致，不支持重命名
  - 对多 getter 固定生成（不提供 getter policy）
  - `Array` to-many 永不生成 setter
  - `Set` to-many 批量替换 helper 受 `relationshipSetterPolicy` 控制
- 完成 `convenience init` 自动生成（可通过 `generateInit: false` 关闭）

验收标准：

- 示例模型可成功编译
- 违反关系声明规则时报编译期错误
- `@Composition` struct 可正确展开字典读写代码，并可通过运行时 round-trip 测试
- `@Composition` 违反约束时可稳定输出编译期诊断
- 构造方法正确包含所有非关系实例存储属性参数（含 `@Ignore`）、排除关系参数，且参数无默认值

### M2: Sort Metadata (v1 Must)

依赖：M1（`.composition` 展开完成后才能生成 composition 子路径）

- 生成 `Keys`（平面持久化 key）
- 生成 `Paths`（支持 relationship/composition 子路径）
- 生成 `__cdFieldTable`（swiftPath -> persistentPath + storageMethod）
- 提供 `NSSortDescriptor` 便捷构造：
  - key-based
  - path-based (`CDPath`)
  - 支持 `order/collation/mode`

验收标准：

- 可通过 `Item.path.magnitude.richter` 构造排序
- 对 renamed 属性使用 `Keys` 排序时落到持久化 key
- to-many 路径用于 sort 时明确拒绝

### M3: Validate Tool

- 解析 xcdatamodeld + Swift 源码（SwiftSyntax）
- 输出分级诊断：`ERROR/WARN/SUGGEST/INFO/MIGRATION`
- 落实硬性规则：
  - Entity Codegen 必须 `Manual/None`
  - to-many relationship 必须 `Optional=true`（模型层）
  - relationship 必须配置 inverse

验收标准：

- 构造错误模型可稳定输出对应错误与迁移提示
- 全通过模型返回零 `ERROR`

### M4: Generate Tool

- 从 xcdatamodeld 生成初始 Swift 模型代码
- 保证生成结果可通过 `validate`
- 生成前置硬性拦截：
  - Codegen 非 `Manual/None` -> 拒绝
  - 缺 inverse -> 拒绝
  - to-many Optional=false -> 拒绝

验收标准：

- 合规模型可生成代码并通过 validate
- 非合规模型生成前即被拒绝

### M5: Runtime Schema For Tests / Debugging

- 为 `@PersistentModel` 生成静态 runtime schema metadata
- 提供从 `[PersistentModel.Type]` 组装 `NSManagedObjectModel` 的 builder / helper
- 支持普通 attribute、relationship、composition 展平
- 支持 `@Attribute(.unique)` 产生单字段 uniqueness metadata
- 约束 `@Attribute(.transient)`：
  - 表示 transient Core Data attribute
  - v1 仅允许与 `.default` 存储配合使用
  - v1 禁止与 `.raw` / `.codable` / `.transformed` / `.composition` 混用
- 复用缓存后的 `NSManagedObjectModel`，避免同一组测试 schema 在一轮测试中重复创建多个 model 实例
- 明确非目标：
  - 不保证与 `xcdatamodeld` 的 hash/version/migration 一致
  - 不作为生产建模能力
  - 不处理历史版本模型
  - 不保证支持“同一目标实体的多条关系且未显式给出 inverseName”的纯代码建模场景

验收标准：

- 不依赖 `.xcdatamodeld` 即可构建测试用 `NSManagedObjectModel`
- 同一组模型类型可创建测试 container 并完成基础读写
- relationship/inverse 可在输入类型集合中正确解析
- `@Attribute(.unique)` 能转化为单字段唯一约束 metadata
- `@Attribute(.transient)` 的 generate / validate 规则与 runtime schema 行为一致
- builder 对不受支持的 primitive 默认值表达式直接报错，不静默丢失默认值
- `unique` / `transient` 完成后，tooling 的 `generate` / `validate` 需补充对应测试，覆盖生成与校验两条路径

## 4. Technical Validations (Mandatory)

1. Macro Expansion Snapshot
- 对典型模型做展开快照测试（使用 `assertMacroExpansion`），防止回归
- 覆盖：属性展开、关系展开、构造方法、Keys/Paths 生成、`@Composition` struct 展开

2. Composition Runtime Validation
- SQLite store + iOS 17+ 场景读写验证
- 非支持环境输出明确诊断与迁移提示

3. Sort Path Validation
- relationship 子路径排序
- composition 子路径排序
- renamed 字段排序

4. Storage Mapping Validation
- `.raw` 枚举映射
- `.codable` 失败策略（`decodeFailurePolicy`）
- `.transformed` 转换失败策略

5. Constraint Validation
- Codegen / inverse / to-many optional 三条硬约束

## 5. Open Decisions

1. `SortCollation` 与 `SortExecutionMode` 的最小支持集合
- 明确哪些模式保证可下推 store，哪些仅内存有效
2. Runtime schema builder 的公开命名
- `NSManagedObjectModel.makeRuntimeModel` 或独立 builder 类型，待实现时收敛

## 6. Delivery Checklist

- [ ] v1 宏能力完成并有测试（含 `@Composition`）
- [ ] v1 构造方法生成完成并有测试
- [ ] v1 排序路径能力完成并有测试
- [ ] validate 工具完成并接入 CI
- [ ] generate 工具完成并接入命令入口
- [ ] 规范文档与实现行为一致
- [x] `tagsCount` 决策收敛（v1 不自动生成 `*Count`，通过文档与诊断引导 `context.count(for:)`）

## 7. Current Sprint Plan (PersistentModel)

当前冲刺按“实现一项 -> 立刻测试一项”推进：

1. `TypedPath` 关系辅助类型编译通过。  
   Test: `swift build`
2. 文档参数与语义对齐（去除 `relationshipGetterPolicy`）。  
   Test: `rg "relationshipGetterPolicy" Specification.md DesignNotes.md ImplementationPlan.md`
3. 修复 `@PersistentModel` 参数解析（尤其 `.none`）。  
   Test: `swift test --filter MacroDiagnosticTests`
4. 建立 `PersistentModel` 展开快照基线。  
   Test: `swift test --filter MacroExpansionSnapshotTests`
5. 按子能力补齐（Keys/Paths/FieldTable/init/to-many helpers）的诊断与快照。  
   Test: 每项新增测试后执行对应 `--filter`，最后 `swift test`

## 8. PersistentModel Status (Now)

已实现：

- 参数解析：`generateInit` / `relationshipSetterPolicy` / `relationshipCountPolicy`
- `Keys` / `Paths` / `PathRoot` / `path` / `__cdFieldTable`
- 构造方法生成（仅非关系实例存储属性，含 `@Ignore`，无默认参数）
- 关系 accessor 与 helper（通过内部 `@_CDRelationship`）
- 关系声明基础诊断（to-many 不可选、to-one 必须可选）
- `relationshipSetterPolicy: .warning` 对 setter 与 helper 的 deprecation 提示
- 关系目标类型 `T: PersistentEntity` 约束（由 `_CDRelationshipMacroValidation.requirePersistentEntity` 编译期强制）
- `relationshipCountPolicy` 在 v1 仅作规范引导（非 `.none` 给 warning，不生成 `*Count`）
- `@objc(ClassName)` 显式声明强校验（缺失时报错；当前宏角色不支持自动注入类型属性）
