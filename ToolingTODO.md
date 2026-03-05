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

## 2. Model Loading

- `[ ]` 支持加载 `.xcdatamodeld`
- `[ ]` 支持加载 `.xcdatamodel`
- `[ ]` 支持加载 `.momd`
- `[ ]` 支持 `modelVersion` 显式选择
- `[ ]` 默认选择 `xccurrentversion`
- `[ ]` 缺失 `xccurrentversion` 时回退到最新版本
- `[ ]` 支持 `momc` 自动发现
- `[ ]` 支持 `momcBin` 手动覆盖

## 3. IR

- `[ ]` 定义实体 IR
- `[ ]` 定义属性 IR
- `[ ]` 定义关系 IR
- `[ ]` 定义 composition IR
- `[ ]` 定义 storage method IR
- `[ ]` 定义生成策略 IR
- `[ ]` 提供 `inspect` 可复用输出模型

## 4. Generate Engine

- `[ ]` 根据模型生成实体代码计划
- `[ ]` 生成 `@objc(...)`
- `[ ]` 生成 `@PersistentModel(...)`
- `[ ]` 生成属性声明
- `[ ]` 生成关系声明
- `[ ]` 生成 composition 对应代码
- `[ ]` 生成 `@Attribute(...)` 参数
- `[ ]` 生成 `@Ignore` 对应保留逻辑
- `[ ]` 支持 `generateInit`
- `[ ]` 支持 `relationshipSetterPolicy`
- `[ ]` 支持 `relationshipCountPolicy`
- `[ ]` 支持默认文件头模板

## 5. File Planning And Writing

- `[ ]` 定义 file plan 模型
- `[ ]` 支持单文件输出
- `[ ]` 支持按 entity 拆分输出
- `[ ]` 生成文件带稳定标记，便于后续覆盖/清理
- `[ ]` 支持 `overwrite = none`
- `[ ]` 支持 `overwrite = changed`
- `[ ]` 支持 `overwrite = all`
- `[ ]` 支持 `cleanStale`
- `[ ]` 限制 stale 清理只在 `outputDir` 内进行
- `[ ]` 支持 `dryRun`
- `[ ]` 支持 `swift-format`

## 6. Validate Engine

- `[ ]` 校验实体是否一一对应
- `[ ]` 校验属性名与 `originalName`
- `[ ]` 校验 storage method
- `[ ]` 校验关系方向与基数
- `[ ]` 校验 ordered / unordered to-many
- `[ ]` 校验 composition 子路径
- `[ ]` 校验生成代码中的 `Keys`
- `[ ]` 校验生成代码中的 `path`
- `[ ]` 校验生成代码中的 `__cdFieldTable`
- `[ ]` 实现 `quick` 模式
- `[ ]` 实现 `strict` 模式

## 7. CLI

- `[x]` 创建 `cde-tool` target
- `[x]` 使用 `Swift Argument Parser`
- `[x]` 提供 `init-config`
- `[x]` 提供 `generate` 命令骨架
- `[x]` 提供 `validate` 命令骨架
- `[x]` 提供 `inspect` 命令骨架
- `[ ]` 将 `generate` 接入 `ToolingCore`
- `[ ]` 将 `validate` 接入 `ToolingCore`
- `[ ]` 将 `inspect` 接入 `ToolingCore`
- `[ ]` 支持 `--config`
- `[ ]` 支持 `json` 输出
- `[ ]` 支持 `sarif` 输出
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
- `[ ]` 模型版本选择测试
- `[ ]` IR 构建测试
- `[ ]` generate file plan 测试
- `[ ]` overwrite / clean-stale 测试
- `[ ]` validate quick 测试
- `[ ]` validate strict 测试
- `[ ]` CLI `init-config` 集成测试
- `[ ]` CLI 参数解析测试
- `[ ]` CLI exit code 测试

## 11. Immediate Next Steps

- `1.` 开始实现 model loader 与版本选择
- `2.` 为 `generate` / `validate` 建立 service 层入口
- `3.` 定义基础 IR（entity / attribute / relationship / composition）
- `4.` 将 CLI `--config` 接入 `ToolingCore`
