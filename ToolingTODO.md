# Tooling TODO

## Status Legend

- `[x]` done
- `[-]` in progress
- `[ ]` pending

## Core Principles

- `CoreDataEvolutionToolingCore` 承担主要功能代码。
- `CDETool` 只保留 CLI adapter、参数解析、stdout/stderr、exit code。
- 主要测试放在 `ToolingCore`。
- CLI 只做薄层集成测试。

## 1. ToolingCore Foundations

- `[x]` 创建独立 target：`CoreDataEvolutionToolingCore`
- `[x]` 将默认配置模板迁移到 `ToolingCore`
- `[x]` 将通用错误码模型迁移到 `ToolingCore`
- `[x]` 创建统一请求模型
- `[x]` 创建统一结果模型
- `[x]` 创建 diagnostics / issue 数据结构
- `[x]` 创建 schema version 校验与升级提示逻辑
- `[x]` 创建配置文件读取与命令行覆盖合并逻辑
- `[x]` 创建共享 `typeMappings` 与 `attributeRules` 配置模型
- `[x]` 创建 `bootstrap-config` 请求/结果/服务骨架

## 2. Model Loading

- `[x]` 支持加载 `.xcdatamodeld`
- `[x]` 支持加载 `.xcdatamodel`
- `[x]` 支持加载 `.momd`
- `[x]` 支持 `modelVersion` 显式选择
- `[x]` 默认选择 `xccurrentversion`
- `[x]` 缺失 `xccurrentversion` 时回退到最新版本
- `[x]` `.xccurrentversion` 损坏或指向缺失版本时直接报错
- `[x]` 支持 `momc` 自动发现
- `[x]` 支持 `momcBin` 手动覆盖
- `[x]` 清理源码模型编译产生的临时 `.mom` / `.momd`

## 2.1. Pre-IR Hardening

- `[x]` 建立 `NSAttributeType -> typeMappings key` 中心映射
- `[x]` 明确 `storageMethod == nil` 等价于 `.default`
- `[x]` 明确 `decodeFailurePolicy` 的优先级：attribute > request default
- `[x]` 增加配置语义校验层
- `[x]` 校验 `singleFile` 与 `splitByEntity` 冲突
- `[x]` 校验 `attributeRules` 指向不存在的 entity / field
- `[x]` 将 CLI 可覆盖参数改为可区分“未传入”
- `[x]` 为 `inspect` 请求补充 `momcBin`
- `[x]` 拆分 `relationshipSetterPolicy` 与 `relationshipCountPolicy` 枚举
- `[x]` bootstrap-config 写回实际解析出的 `modelVersion`

## 3. IR

- `[x]` 定义实体 IR
- `[x]` 定义属性 IR
- `[x]` 定义关系 IR
- `[x]` 定义 composition IR（占位表示，暂不自动推断）
- `[x]` 定义 storage method IR
- `[x]` 定义生成策略 IR
- `[x]` 提供 `inspect` 可复用输出模型

## 4. Generate Engine

- `[x]` 根据模型生成实体代码计划（内存中的 generated sources）
- `[x]` 生成 `@objc(...)`
- `[x]` 生成 `@PersistentModel(...)`
- `[x]` 生成属性声明
- `[x]` 生成关系声明
- `[x]` 生成 composition 对应代码
- `[x]` 生成 `@Attribute(...)` 参数
- `[x]` 根据 `typeMappings` 解析默认 Swift 类型
- `[x]` 根据 `attributeRules` 生成重命名属性
- `[x]` 根据 `attributeRules` 生成类型与 storage method 覆盖
- `[x]` 支持 `generateInit`
- `[x]` 支持 `relationshipSetterPolicy`
- `[x]` 支持 `relationshipCountPolicy`
- `[x]` 接线 `headerTemplate` 文件解析与 CLI/config 输入

## 5. File Planning And Writing

- `[x]` 定义 file plan 模型
- `[x]` 支持单文件输出
- `[x]` 支持按 entity 拆分输出
- `[x]` 生成文件带稳定标记，便于后续覆盖/清理
- `[x]` 支持 `overwrite = none`
- `[x]` 支持 `overwrite = changed`
- `[x]` 支持 `overwrite = all`
- `[x]` 支持 `cleanStale`
- `[x]` 限制 stale 清理只在 `outputDir` 内进行
- `[x]` 支持 `dryRun`
- `[x]` 支持 `swift-format`
- `[x]` 支持 `SwiftFormat`
- `[x]` 将 formatter 执行限制在 CLI/adapter 层

## 6. Validate Engine

- `[x]` 定义 source-side IR（entity / property / relationship / macro arguments）
- `[x]` 解析 `@PersistentModel` / `@objc` / `@Attribute` / `@Ignore`
- `[x]` 解析代码中的默认值字面量
- `[x]` 校验实体是否一一对应
- `[x]` 校验属性名与 `originalName`
- `[x]` 根据 `attributeRules` 校验属性重命名
- `[x]` 根据 `typeMappings` 校验默认类型映射
- `[x]` 根据 `attributeRules` 校验属性级类型与 storage method 覆盖
- `[x]` 校验额外 stored property 是否显式标记为 `@Ignore`
- `[x]` 校验 `@Ignore` 不得遮蔽持久化属性
- `[x]` 校验默认存储的非 optional 持久化属性默认值是否与模型一致
- `[x]` 校验 optional 持久化属性允许省略 `= nil`
- `[x]` 校验 storage method
- `[x]` 校验关系方向与基数
- `[x]` 校验 ordered / unordered to-many
- `[ ]` 校验 composition 子路径
- `[x]` 校验类级 `@PersistentModel(...)` 参数
- `[x]` 实现 `quick` 模式（结构级 source/model/config 对比）
- `[ ]` 实现 `strict` 模式（在 quick 之上做 managed file 精确漂移比对）

## 7. CLI

- `[x]` 创建 `cde-tool` target
- `[x]` 使用 `Swift Argument Parser`
- `[x]` 提供 `init-config`
- `[x]` 提供 `bootstrap-config`
- `[x]` 提供 `generate` 命令骨架
- `[x]` 提供 `validate` 命令骨架
- `[x]` 提供 `inspect` 命令骨架
- `[x]` 将 `inspect` 接入 `ToolingCore`
- `[x]` 将 `generate` 接入 `ToolingCore`
- `[x]` 将 `validate` 接入 `ToolingCore`
- `[x]` `generate` 支持 `--config`
- `[x]` `validate` 支持 `--config`
- `[x]` `inspect` 支持 `--config`
- `[x]` 支持 `json` 输出
- `[x]` 支持 `sarif` 输出
- `[ ]` 统一 CLI 文本错误与提示

## 8. Plugin

- `[ ]` 确定 plugin 形态
- `[ ]` 确定 plugin 是否直接调用 CLI
- `[ ]` build tool plugin 参数映射
- `[ ]` 将 `validate` 接入 plugin
- `[ ]` 将 `generate` 接入 plugin

## 9. GUI

- `[ ]` 确定 GUI 是否直接依赖 `ToolingCore`
- `[ ]` 提供结构化 diff 数据
- `[ ]` 提供 diagnostics 列表输出
- `[ ]` 提供 generate preview 数据

## 10. Tests

- `[x]` 为 `ToolingCore` 创建独立测试 target
- `[x]` 配置模板测试
- `[x]` schema version 测试
- `[x]` config 合并测试
- `[x]` `init-config` service 测试
- `[x]` `bootstrap-config` service 测试
- `[x]` 模型版本选择测试
- `[x]` IR 构建测试
- `[x]` inspect service 测试
- `[x]` generate source renderer 测试
- `[x]` generate service 测试
- `[x]` generate file plan 测试
- `[x]` overwrite / clean-stale 测试
- `[x]` validate quick 测试
- `[ ]` validate strict 测试
- `[x]` validate `@Ignore` 规则测试
- `[x]` validate 默认值不一致测试
- `[ ]` CLI `init-config` 集成测试
- `[ ]` CLI 参数解析测试
- `[ ]` CLI exit code 测试

## 11. Immediate Next Steps

- `1.` 在 validate 上叠加 strict 的 managed file 精确漂移比对
- `2.` 为 validate CLI 增加参数解析 / exit code / report 的独立集成测试
- `3.` 视需要补 composition 子路径校验

## 12. Deferred / Known Gaps

- `[ ]` `bootstrap-config` 仍不会自动识别 enum/raw 候选字段，只保留手动调整空间。
- `[ ]` `bootstrap-config` 仍不会自动推断 composition 候选字段。
- `[ ]` `generate.attributeRules` 与 `validate.attributeRules` 仍是两份独立配置，暂不提供引用/复用语法。
- `[ ]` `generate` / `validate` service 接线后，仍需在“合并 CLI overrides 后”的 request 层再做一次最终校验。
- `[ ]` 当前 inspect 对未解析字段只发出 diagnostics，不会像 generate/validate 那样直接失败。
- `[ ]` validate v1 假定宏展开结果正确，不直接校验宏生成的 `Keys` / `path` / `__cdFieldTable`；当前只校验足以导出这些成员的源码输入。
- `[ ]` generate 目前不会从模型外信息推断 `@Ignore` 字段。
- `[ ]` tool 仍未提供描述 `@Ignore` / 纯内存属性的额外配置模型。
- `[ ]` generate 当前只会直接使用模型默认值；对于非可选自定义 raw/codable/composition/transformed 类型，仍缺少未来的显式代码默认值规则。
- `[ ]` validate 当前仅实现 `quick`；`strict` 仍未落地。
- `[ ]` validate 当前已支持 `text/json/sarif` 报告输出，但 CLI 集成测试尚未补齐。
- `[ ]` validate 当前只校验 composition 属性声明，不校验 composition 子路径/字段展开细节。
- `[ ]` validate v1 将以“符合当前 tool 生成约定”为准，不尝试判断任意语义等价默认值写法。
- `[ ]` `GenerateService.validateGenerateRequest` 仍通过 `GenerateRequest -> GenerateTemplate` 的中转来复用校验逻辑；后续可提取为直接接受已解析参数的共享验证入口，降低字段漂移风险。
- `[ ]` 只有在未来宏语义允许“代码默认值覆盖模型默认值”时，tool 才会引入默认值配置，并用该值参与代码生成。
