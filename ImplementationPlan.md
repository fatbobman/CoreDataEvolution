# CoreData Macro System Implementation Plan

## 1. Goal

在保留 `xcdatamodeld` 工作流前提下，落地一套可执行的 Core Data 开发范式：

- 宏生成：属性访问、关系访问、排序 key/path 元信息
- 工具能力：`validate` + `generate`
- 强约束：Codegen / inverse / to-many optional 等规范落地

## 2. Version Scope

### v1 (Must)

- `@PersistentModel` / `@Attribute` / `@Ignore` / `@RelationshipInfo`
- `StorageMethod`: `.default` `.raw` `.codable` `.transformed` `.composition`
- 类型安全排序：`Keys + Paths + __cdFieldTable`
- 查询规范：优先 `NSPredicate`（`%K + Keys.rawValue`）
- 工具：`validate` 与 `generate` 的硬性校验与迁移提示

### v2 (Next)

- `CDPredicate`：类型安全表达式自动转换到 `NSPredicate`

## 3. Milestones

### M1: Macro Skeleton + Hard Constraints

- 完成 `@PersistentModel` 基本展开（`@objc` 注入规则、`CoreDataKeys` conformance、访问权限继承）
- 完成 `@PersistentModel` 的 `serializationErrorPolicy` 参数，`.codable` / `.transformed` 展开代码统一走该策略
- 完成 `@Attribute` 的 `.default/.raw/.codable/.transformed/.composition` 展开
- 完成 `@Composition` 宏：解析 struct 成员，生成 `[String: Any]` 字典组装/解构代码
- 完成 `@Ignore` 行为：仅对 `var` 生效，`let` 默认忽略
- 完成关系规则：
  - 代码层：to-many 非可选，to-one 可选
  - 关系属性名必须与 xcdatamodeld 一致，不支持重命名
  - `Array` to-many 永不生成 setter
  - `Set` to-many setter 受策略控制
- 完成 `convenience init` 自动生成（可通过 `generateInit: false` 关闭）

验收标准：

- 示例模型可成功编译
- 违反关系声明规则时报编译期错误
- `@Composition` struct 可正确展开字典读写代码
- 构造方法正确包含属性参数、排除关系参数

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
- `.codable` 序列化失败策略（三种 `SerializationErrorPolicy`）
- `.transformed` 转换失败策略

5. Constraint Validation
- Codegen / inverse / to-many optional 三条硬约束

## 5. Open Decisions

1. `tagsCount` 是否在 v1 实现（当前待议）
- 若实现：仅在存在 `@RelationshipInfo` 且 `relationshipCountPolicy != .none` 时生成
- 若不实现：删除 count 相关策略与示例

2. `SortCollation` 与 `SortExecutionMode` 的最小支持集合
- 明确哪些模式保证可下推 store，哪些仅内存有效

## 6. Delivery Checklist

- [ ] v1 宏能力完成并有测试（含 `@Composition`）
- [ ] v1 构造方法生成完成并有测试
- [ ] v1 排序路径能力完成并有测试
- [ ] validate 工具完成并接入 CI
- [ ] generate 工具完成并接入命令入口
- [ ] 规范文档与实现行为一致
- [ ] `tagsCount` 决策收敛
