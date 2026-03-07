# CoreDataEvolution Tooling CLI (WIP)

## 1. 目标与范围

CLI v1 先解决两件事：

- `generate`: 根据 Core Data 模型生成 Swift 模型代码（宏风格）。
- `validate`: 验证模型与代码是否对齐，提前发现漂移。

后续的 SPM Plugin 和 GUI 版本都复用同一套核心引擎（解析 -> IR -> 生成 -> 校验），只替换入口层。

## 2. 命令草案

### `cde-tool generate`

用途：从 source model（`.xcdatamodeld` / `.xcdatamodel`）生成 Swift 文件。

当前 `ToolingCore` 已完成：

- model -> IR -> generated sources -> file plan -> disk writes
- `@objc` / `@PersistentModel` / `@Attribute` / relationship / composition 声明渲染
- `typeMappings`、`attributeRules` 与 `relationshipRules` 的生成侧解析
- `overwrite` / `clean-stale` / `dry-run`
- 单文件与按 entity 拆分输出

### `cde-tool validate`

用途：检查“模型文件 + 已有代码”是否一致，不写文件。

补充能力：

- diagnostics 可携带 fix suggestion
- `validate --fix` 可应用安全、可确定的文本修复
- `validate --fix --dry-run` 只预览这些修复，不写文件

### `cde-tool inspect`

用途：输出解析后的中间模型（IR），便于调试和 GUI 展示。

当前行为：

- 读取模型并输出结构化 IR JSON。
- 默认使用内建 `typeMappings` / 空 `attributeRules` / 空 `relationshipRules`。
- 如果提供 `--config`，则读取其中 `generate` 节点的规则来解析属性名、存储方式、类型映射。
- `inspect --config` 与 `generate/validate` 一样，按配置文件所在目录解析相对路径。
- 对于尚未补完的字段，`inspect` 会输出 diagnostics，但仍尽量产出可读 IR。

### `cde-tool init-config`

用途：导出默认配置模板 JSON，作为项目配置起点。

### `cde-tool bootstrap-config`

用途：根据具体 Core Data 模型生成一份“可编辑配置草案”，适合作为首次接入工具时的起点。

推荐工作流：

1. `bootstrap-config` 根据模型生成配置草案。
2. 手动修改 `typeMappings`、`attributeRules` 与 `relationshipRules`。
3. `generate` 根据“模型 + 配置”生成代码。
4. `validate` 使用同一份配置做校验。

### `cde-tool version`

用途：输出当前 `cde-tool` 的版本和构建元数据。

支持三种入口：

- `cde-tool --version`
  - 输出简洁版本号，适合脚本或 CI 读取。
- `cde-tool -v`
  - 输出详细版本信息（tag / commit / describe / dirty）。
- `cde-tool version`
  - 输出与 `-v` 相同的详细版本信息。

版本策略：

- `cde-tool` 版本应与当前 `CoreDataEvolution` tag 保持一致。
- 如果通过 `Scripts/build-cde-tool.sh` 从 git checkout 构建，脚本会在构建时注入当前 tag / commit / dirty 信息。
- 直接 `swift build` / `swift run` 的源码构建默认显示开发占位版本（例如 `0.0.0-dev`）。
- 如果源码不是 git checkout（例如下载的 zip），则无法保证拿到 tag / commit，工具会退回到开发占位元数据。

### `Scripts/build-cde-tool.sh`

用途：以 release 模式构建 `cde-tool`，并在构建产物中注入当前仓库的 tag / commit 元数据。

用法：

```bash
bash Scripts/build-cde-tool.sh
bash Scripts/build-cde-tool.sh --copy-to ~/bin
bash Scripts/build-cde-tool.sh --copy-to ~/bin --force
```

行为：

- 使用 `swift build -c release --product cde-tool` 构建。
- 默认只打印最终产物路径。
- 通过 `--copy-to <dir>` 可将二进制复制到指定目录。
- 不默认写入系统全局路径。
- 构建脚本会暂时重写内部版本元数据文件，并在结束后恢复，避免把版本注入结果留在工作区。

### Release 策略

v1 的版本与发行策略分为两层：

- 本地 / 开发构建：
  - 保持当前 fallback 机制。
  - `--version / -v / version` 输出：
    - version
    - tag
    - commit
    - describe
    - dirty
- GitHub Release：
  - 通过 GitHub Action 在 tag 构建时：
    1. 构建二进制
    2. 生成 `version.json`
    3. 生成 checksum
    4. 上传 release assets

约定：

- 不使用 pre-commit / pre-push hook 注入版本信息。
- 版本注入属于构建与发布行为，不属于普通源码编辑行为。

## 3. 配置文件（JSON）

为避免每次传入大量参数，CLI 支持：

- `--config <path/to/cde-tool.json>`

参数优先级：

- 命令行参数 > 配置文件 > 内置默认值

推荐结构（按命令分段）：

```json
{
  "generate": {
    "modelPath": "Models/AppModel.xcdatamodeld",
    "modelVersion": null,
    "momcBin": null,
    "outputDir": "Generated/CoreDataEvolution",
    "moduleName": "AppModels",
    "typeMappings": {
      "String": { "swiftType": "String" },
      "Boolean": { "swiftType": "Bool" },
      "Integer 16": { "swiftType": "Int16" },
      "Integer 32": { "swiftType": "Int32" },
      "Integer 64": { "swiftType": "Int64" },
      "Float": { "swiftType": "Float" },
      "Double": { "swiftType": "Double" },
      "Decimal": { "swiftType": "Decimal" },
      "Date": { "swiftType": "Date" },
      "Binary": { "swiftType": "Data" },
      "UUID": { "swiftType": "UUID" },
      "URI": { "swiftType": "URL" }
    },
    "attributeRules": {
      "Item": {
        "name": {
          "swiftName": "title"
        },
        "status_raw": {
          "swiftType": "ItemStatus",
          "storageMethod": "raw"
        },
        "config_blob": {
          "swiftType": "ItemConfig",
          "storageMethod": "codable"
        }
      }
    },
    "relationshipRules": {
      "Item": {
        "oldtags": {
          "swiftName": "tags"
        }
      },
      "Tag": {
        "item_ref": {
          "swiftName": "owner"
        }
      }
    },
    "accessLevel": "internal",
    "singleFile": false,
    "splitByEntity": true,
    "overwrite": "none",
    "cleanStale": false,
    "dryRun": false,
    "format": "none",
    "headerTemplate": null,
    "generateInit": false,
    "relationshipSetterPolicy": "warning",
    "relationshipCountPolicy": "none",
    "defaultDecodeFailurePolicy": "fallbackToDefaultValue"
  },
  "validate": {
    "modelPath": "Models/AppModel.xcdatamodeld",
    "modelVersion": null,
    "momcBin": null,
    "sourceDir": "Sources/AppModels",
    "moduleName": "AppModels",
    "typeMappings": {
      "String": { "swiftType": "String" },
      "Boolean": { "swiftType": "Bool" },
      "Integer 16": { "swiftType": "Int16" },
      "Integer 32": { "swiftType": "Int32" },
      "Integer 64": { "swiftType": "Int64" },
      "Float": { "swiftType": "Float" },
      "Double": { "swiftType": "Double" },
      "Decimal": { "swiftType": "Decimal" },
      "Date": { "swiftType": "Date" },
      "Binary": { "swiftType": "Data" },
      "UUID": { "swiftType": "UUID" },
      "URI": { "swiftType": "URL" }
    },
    "attributeRules": {
      "Item": {
        "name": {
          "swiftName": "title"
        },
        "status_raw": {
          "swiftType": "ItemStatus",
          "storageMethod": "raw"
        },
        "config_blob": {
          "swiftType": "ItemConfig",
          "storageMethod": "codable"
        }
      }
    },
    "relationshipRules": {
      "Item": {
        "oldtags": {
          "swiftName": "tags"
        }
      },
      "Tag": {
        "item_ref": {
          "swiftName": "owner"
        }
      }
    },
    "include": [],
    "exclude": [],
    "level": "conformance",
    "report": "text",
    "failOnWarning": false,
    "maxIssues": 200
  }
}
```

配置读取规则：

- 运行 `cde-tool generate` 时读取 `generate` 节点。
- 运行 `cde-tool validate` 时读取 `validate` 节点。
- 运行 `cde-tool inspect --config` 时读取 `generate` 节点。
- 命令行显式传入参数优先覆盖配置文件同名字段。

`typeMappings` 约定：

- 结构：`CoreDataPrimitiveType -> { swiftType }`
- 作用：定义默认的 Swift 类型映射规则。
- 默认原则：精确类型映射，不做隐式数值转换。
- 例如：
  - `Float -> Float`
  - `Double -> Double`
  - `Integer 64 -> Int64`
  - `Binary -> Data`
- 不建议默认：
  - `Float -> Double`
  - `Integer 64 -> Int`

`attributeRules` 约定：

- 结构：`EntityName.persistentField -> rule object`
- 每个属性规则可包含：
  - `swiftName`
  - `swiftType`
  - `storageMethod`
  - `transformerType`
  - `decodeFailurePolicy`
- 作用：
  - `generate` 用于生成重命名属性与 `@Attribute(...)` 覆盖
  - `validate` 用于按同一规则校验代码与模型是否一致
- v1 仅用于 attribute，不用于 relationship

`relationshipRules` 约定：

- 结构：`EntityName.persistentRelationship -> rule object`
- 当前规则对象只包含：
  - `swiftName`
- 作用：
  - `generate` 用于生成 relationship 重命名与 `@Relationship(persistentName: ...)`
  - `validate` 用于按同一规则校验 relationship 重命名是否一致
- 如果关系两侧都需要重命名，需要分别在两侧实体的 `relationshipRules` 中单独声明。
- `@Relationship(inverse: ...)` 仍然使用对端 relationship 的持久化名字，不使用对端 Swift 属性名。

`Binary` / `codable` 约定：

- 默认映射里，`Binary -> Data`
- 如果某个 `Binary` 字段要映射成业务类型，应使用属性级规则显式声明：
  - `swiftType: "ItemConfig"`
  - `storageMethod: "codable"`
- 也就是说，`Binary -> CodableType` 不是默认规则，而是字段级覆盖规则。

### 3.1 默认配置模板导出

建议支持：

- `cde-tool init-config --output cde-tool.json`
- `cde-tool init-config --stdout`

参数草案：

- `--output <path>`
  - 可选，默认 `./cde-tool.json`。
- `--stdout`
  - 可选。输出到标准输出，不写文件。
- `--force`
  - 可选。覆盖已存在配置文件。
- `--preset <minimal|full>`
  - 可选，默认 `full`。
  - `minimal`: 仅输出 required 字段。
  - `full`: 输出完整字段及默认值。

行为约束：

- 目标文件已存在且未指定 `--force` 时返回非零退出码。
- 生成模板始终使用最新 schema 版本字段。
- 模板中可添加 `"$schemaVersion"` 方便后续升级迁移。

### 3.2 `init-config` 退出码与错误文案

退出码建议：

- `0`: 成功导出模板。
- `1`: 用户可修复错误（参数冲突、目标文件已存在、路径不可写）。
- `2`: 运行时异常（I/O 异常、编码失败、未知内部错误）。

标准错误文案建议：

| 场景 | 文案示例 | 退出码 |
| --- | --- | --- |
| `--output` 与 `--stdout` 同时出现 | `error: --output and --stdout cannot be used together.` | `1` |
| 目标文件存在且未 `--force` | `error: config file already exists at '<path>'. Use --force to overwrite.` | `1` |
| `--preset` 非法值 | `error: unsupported preset '<value>'. Allowed: minimal, full.` | `1` |
| 输出目录不存在 | `error: output directory does not exist: '<dir>'.` | `1` |
| 无写权限 | `error: cannot write config file to '<path>' (permission denied).` | `1` |
| JSON 序列化失败 | `error: failed to encode config template as JSON.` | `2` |
| 未知内部错误 | `error: init-config failed due to an internal error.` | `2` |

日志约定建议：

- 成功写文件时输出：`wrote config template to <path>`
- `--stdout` 模式下不输出额外日志，仅输出 JSON 内容。

### 3.3 模型驱动配置草案导出

建议支持：

- `cde-tool bootstrap-config --model-path Models/AppModel.xcdatamodeld --output cde-tool.json`
- `cde-tool bootstrap-config --model-path Models/AppModel.xcdatamodeld --stdout`

参数草案：

- `--model-path <path>`
  - required。仅支持 source model：`.xcdatamodeld`、`.xcdatamodel`。
- `--model-version <name>`
  - optional。显式指定模型版本。
- `--momc-bin <path>`
  - optional。覆盖 `momc` 自动发现。
- `--module-name <name>`
  - optional。默认 `AppModels`。
- `--output-dir <path>`
  - optional。默认 `Generated/CoreDataEvolution`。
- `--source-dir <path>`
  - optional。默认 `Sources/AppModels`。
- `--output <path>`
  - optional。默认 `./cde-tool.json`。
- `--stdout`
  - optional。输出到标准输出，不写文件。
- `--force`
  - optional。覆盖已存在配置文件。

输出约定：

- 生成完整 `typeMappings`，方便用户直接修改默认类型映射策略。
- 为每个实体的每个 attribute 生成一条 `attributeRules` 占位规则。
- 如果未显式传入 `modelVersion`，导出的配置会写入实际解析出的版本名，保证后续 `generate` / `validate` 可复现。
- 如果 `swiftName == persistentField`，默认省略 `swiftName`，保持草案简洁。
- 只有当属性需要重命名时，才显式填写 `swiftName`。
- 对 `Transformable` 字段：
  - 自动生成 `storageMethod: "transformed"`
  - 如果模型里已有 transformer 名称，则带出 `transformerType`
  - 同时在 diagnostics 中提示用户补齐/确认 `swiftType`
- 对 `Binary` 字段：
  - 保持默认 `Binary -> Data` 映射
  - 在 diagnostics 中提示开发者，如需业务类型应改成 `storageMethod: "codable"`
- 对普通基础字段，不自动写入 `storageMethod`，保持可编辑但不过度冗余。
- v1 不为 relationship 生成配置规则。

设计边界：

- `init-config` 是“通用模板”，不依赖具体模型。
- `bootstrap-config` 是“模型驱动草案”，依赖具体模型。
- 当 `bootstrap-config` 将配置写入文件时，会把路径字段重写为相对于配置文件位置的路径，保证后续 `generate/validate/inspect` 可复现。
- 两者不合并，避免命令语义混淆。

## 4. `generate` 参数设计（v1）

### 4.1 模型输入参数

- `--model-path <path>`
  - 仅支持 source model：`.xcdatamodeld`、`.xcdatamodel`。
  - v1 推荐主输入：`.xcdatamodeld`。
- `--model-version <name>`
  - 可选。用于显式指定 `.xcdatamodeld` 版本。
  - 未指定时：默认使用当前版本（`*.xccurrentversion`），若缺失则回退到最新版本。
- `--momc-bin <path>`
  - 可选。覆盖 `xcrun --find momc` 自动查找逻辑。

自动选择“当前模型版本”的规则：

1. 如果命令行或配置中显式提供 `modelVersion`，优先使用该版本。
2. 否则读取 `.xcdatamodeld/.xccurrentversion` 中的 `_XCCurrentVersionName`。
3. 如果 `.xccurrentversion` 缺失，再回退到目录中按标准自然排序后的最新 `.xcdatamodel`。

说明：

- `.xccurrentversion` 是 Xcode / Core Data 对“当前版本”的权威来源。
- “回退到最新版本”仅是容错策略，不应替代对 `.xccurrentversion` 的维护。
- 如果 `.xccurrentversion` 存在但内容损坏，或指向了不存在的版本，tool 会直接报错，不会静默回退到最新版本。
- `modelVersion` 同时接受 `V2` 和 `V2.xcdatamodel` 两种写法。

### 4.2 输出参数

- `--output-dir <path>`
  - 生成文件目标目录。
- `--module-name <name>`
  - 代码中 `import` 与类型引用需要的模块名。
- `--type-mappings`
  - v1 不单独提供 CLI 参数，推荐在 JSON 配置中声明。
- `--attribute-rules`
  - v1 不单独提供 CLI 参数，推荐在 JSON 配置中声明。

如果是首次接入，推荐先运行 `bootstrap-config` 生成这些字段，再手动修改。
- `--access-level <internal|public>`
  - 生成代码默认可见性。
- `--single-file`
  - 单文件输出模式（默认 false）。
- `--split-by-entity`
  - 按实体拆分多个文件（默认 true）。
- `--emit-extension-stubs`
  - 为每个实体额外创建一次 hand-written companion extension 示例文件。
  - 适合在 `exact` 模式下承载方法和计算属性。

### 4.3 生成行为参数

- `--overwrite <mode>`
  - `none`: 默认，目标存在则失败。
  - `changed`: 仅覆盖内容不同且带生成标记的文件。
  - `all`: 覆盖所有目标文件（限目标目录）。
- `--clean-stale`
  - 删除旧的“已生成但本轮不存在”的文件（仅处理带生成标记的文件）。
- `--dry-run`
  - 不写磁盘，打印变更摘要。

当前生成边界：

- 生成结果始终遵循模型中的 optionality；v1 不支持通过配置把 optional 字段提升为非 optional Swift 属性。
- tooling v1 只接受 source model：`.xcdatamodeld`、`.xcdatamodel`。
- 已编译的 `.mom` / `.momd` 不作为 generate / bootstrap-config / inspect / validate 的正式输入。
- source model 中的 entity 不得启用 Xcode code generation 模式，例如 `class`、`module`、`category`。
- Xcode 的 Manual/None 通常表现为不写 `codeGenerationType`；tool 将“缺省值”视为合法输入。
- 如果 source model 仍显式使用 `class` / `module` / `category`，tool 会在加载前直接失败，避免与 tooling-generated macro code 冲突。
- 对于 `storageMethod == default` 的非 optional 字段，tool 必须直接使用模型默认值；如果模型没有默认值，generate 会直接报错。
- tool 当前直接遵循模型端“至少 optional 或有默认值”的规范，不额外替属性做语义转换。
- `@Ignore` 不属于模型信息，无法从 `xcdatamodeld` 推断；因此 model-to-code 生成不会创建 `@Ignore` 属性。
- 对于非 optional 的自定义 `raw` / `codable` / `composition` / `transformed` 类型，当前会直接报错；即使底层持久化字段在模型中有默认值，v1 也不会尝试把它转换成自定义 Swift 值。
- relationship 生成当前要求模型中的关系同时满足：
  - `optional == true`
  - 存在 inverse relationship
- 如果关系不满足上述约束，generate 会直接报错，而不是输出与当前宏契约不一致的代码。

禁止生成的模型约束：

- 不允许 `Undefined` attribute type。tool 不会为未定义的 Core Data 属性类型推断 Swift 类型。
- 不允许非 optional 且没有模型默认值的持久化属性。
- 不允许非 optional relationship。
- 不允许没有 inverse relationship 的 relationship。
- tool 当前不对上述模型做“自动转换后继续生成”。遇到这些情况时，generate 会直接失败，要求先修正模型或等待未来明确支持的配置能力。

未来演进约定：

- 如果后续宏语义允许“代码中的默认值覆盖模型默认值”，tool 才会增加默认值相关配置。
- 届时会通过显式配置项提供默认值，并由该值参与代码生成；v1 不提前引入这套能力。
- `--format <none|swift-format|swiftformat>`
  - 是否在写入前格式化。
  - `swift-format` 对应 Apple `swift-format`。
  - `swiftformat` 对应 Nick Lockwood `SwiftFormat`。
  - formatter 执行属于 CLI/adapter 层，`ToolingCore` 只表达模式，不直接依赖外部工具。
- `--header-template <path>`
  - 自定义文件头模板（如项目统一版权头）。

### 4.4 宏生成策略参数（映射到当前宏能力）

- `--generate-init <true|false>`
- `--relationship-setter-policy <none|warning|plain>`
- `--relationship-count-policy <none|warning|plain>`
- `--default-decode-failure-policy <fallbackToDefaultValue|debugAssertNil>`

说明：这些参数作为“生成代码默认策略”，具体属性仍允许在代码层用 `@Attribute(...)` 覆盖。

默认值差异说明：

- CLI `generate` 默认 `relationshipSetterPolicy = warning`（更保守，优先提示关系批量写入成本）。
- `@PersistentModel` 宏本身默认 `relationshipSetterPolicy = .none`。
- 这是有意差异：CLI 作为“代码生成入口”采用更安全默认值，宏保持最小侵入默认行为。

### 4.5 `generate` 配置约束（schema 级别）

- `modelPath`: required, string，无默认值。
- `modelVersion`: optional, string/null，默认 `null`（自动选择当前版本，缺失则最新）。
- `momcBin`: optional, string/null，默认 `null`（自动发现）。
- `outputDir`: required, string，无默认值。
- `moduleName`: required, string，无默认值。
- `typeMappings`: optional, object，默认内建精确类型映射表。
- `attributeRules`: optional, object，默认 `{}`。
- `accessLevel`: optional, enum(`internal`,`public`)，默认 `internal`。
- `singleFile`: optional, bool，默认 `false`。
- `splitByEntity`: optional, bool，默认 `true`。
- `singleFile` 与 `splitByEntity` 不能同时为 `true`。
- `overwrite`: optional, enum(`none`,`changed`,`all`)，默认 `none`。
- `cleanStale`: optional, bool，默认 `false`。
- `dryRun`: optional, bool，默认 `false`。
- `format`: optional, enum(`none`,`swift-format`,`swiftformat`)，默认 `none`。
- `headerTemplate`: optional, string/null，默认 `null`。
  - 语义是“模板文件路径”，不是内联文本。
  - 配置文件中的相对路径相对配置文件目录解析。
  - CLI 显式传入的相对路径相对当前工作目录解析。
- `emitExtensionStubs`: optional, bool，默认 `false`。
- `generateInit`: optional, bool，默认 `false`。
- `relationshipSetterPolicy`: optional, enum(`none`,`warning`,`plain`)，默认 `warning`。
- `relationshipCountPolicy`: optional, enum(`none`,`warning`,`plain`)，默认 `none`。
- `defaultDecodeFailurePolicy`: optional, enum(`fallbackToDefaultValue`,`debugAssertNil`)，默认 `fallbackToDefaultValue`。

## 5. `validate` 参数设计（v1）

### 5.1 输入范围

- `--model-path <path>`
- `--momc-bin <path>`
- `--source-dir <path>`
- `--module-name <name>`
- `--access-level <internal|public>`
- `--single-file <bool>`
- `--split-by-entity <bool>`
- `--header-template <path>`
- `--generate-init <bool>`
- `--relationship-setter-policy <none|warning|plain>`
- `--relationship-count-policy <none|warning|plain>`
- `--default-decode-failure-policy <fallbackToDefaultValue|debugAssertNil>`
- `--type-mappings`
  - v1 不单独提供 CLI 参数，推荐在 JSON 配置中声明。
- `--attribute-rules`
  - v1 不单独提供 CLI 参数，推荐在 JSON 配置中声明。
- `--include <glob>`
- `--exclude <glob>`

### 5.2 校验级别

- `--level <conformance|exact>`
  - 默认值：`conformance`。
  - `conformance`: 规则符合模式。只做结构级 source/model/config 对比，不要求 tool-managed 文件与当前生成结果逐字一致。
  - `exact`: 精确一致模式。在 `conformance` 之上，对带 managed marker 的生成文件做精确漂移比对。
  - `exact` 不是默认推荐模式。它更适合 CI / 防漂移场景，而不是会对 generated file 继续运行 formatter/linter rewrite 的日常工作流。

### 5.3 输出与退出码

- `--report <text|json|sarif>`
- `--fail-on-warning`
- `--max-issues <n>`

退出码约定：

- `0`: 无错误。
- `1`: 存在验证错误。
- `2`: 参数或运行时异常（例如模型读取失败）。

### 5.4 `validate` 配置约束（schema 级别）

- `modelPath`: required, string，无默认值。
- `modelVersion`: optional, string/null，默认 `null`（自动选择当前版本，缺失则最新）。
- `momcBin`: optional, string/null，默认 `null`（自动发现）。
- `sourceDir`: required, string，无默认值。
- `moduleName`: required, string，无默认值。
- `typeMappings`: optional, object，默认内建精确类型映射表。
- `attributeRules`: optional, object，默认 `{}`。
- `accessLevel`: optional, enum(`internal`,`public`)，默认 `internal`。
- `singleFile`: optional, bool，默认 `false`。
- `splitByEntity`: optional, bool，默认 `true`。
- `headerTemplate`: optional, string/null，默认 `null`。
- `emitExtensionStubs`: optional, bool，默认 `false`。
- `generateInit`: optional, bool，默认 `false`。
- `relationshipSetterPolicy`: optional, enum(`none`,`warning`,`plain`)，默认 `warning`。
- `relationshipCountPolicy`: optional, enum(`none`,`warning`,`plain`)，默认 `none`。
- `defaultDecodeFailurePolicy`: optional, enum(`fallbackToDefaultValue`,`debugAssertNil`)，默认 `fallbackToDefaultValue`。
- `include`: optional, array<string>，默认 `[]`。
- `exclude`: optional, array<string>，默认 `[]`。
- `level`: optional, enum(`conformance`,`exact`)，默认 `conformance`。
- `report`: optional, enum(`text`,`json`,`sarif`)，默认 `text`。
- `failOnWarning`: optional, bool，默认 `false`。
- `maxIssues`: optional, integer，默认 `200`。

### 5.5 配置语义校验（当前已实现）

- 配置文件除 `"$schemaVersion"` 外，还会做一层语义校验。
- 当前会提前拒绝：
  - `singleFile == true` 且 `splitByEntity == true`
  - `storageMethod: "transformed"` 但缺少 `transformerType`
  - `decodeFailurePolicy` 用在 `default` 或 `composition`
  - 非法或空的 `swiftType` / `swiftName` / `transformerType`
  - `typeMappings` 中未知的 Core Data primitive key
- 当配置已经结合真实模型做校验时，还会进一步拒绝：
  - `attributeRules` 指向不存在的 entity / attribute
  - 默认存储无法从 Core Data primitive 推导出映射 key
  - `raw` / `codable` / `composition` / `transformed` 缺少 `swiftType`

### 5.6 `validate` 结构级规则（session 6 约定）

`validate` 不只是把模型和字符串做比对；它需要先解析源码，构建 source-side IR，再与 model IR 和配置规则做比较。

边界约定：

- `validate` 假定宏展开结果正确
- `validate` 只检查开发者提供的源码输入是否满足模型与工具规则
- 宏展开正确性由宏测试与编译器保障，不属于 tooling validate 的职责

`conformance` 目标：

- 解析 `@PersistentModel`、`@objc`、`@Attribute`、`@Ignore`
- 解析属性/关系类型、可选性和默认值字面量
- 比较模型、配置、源码三者是否一致
- 当前已实现并接入 `cde-tool validate`

`exact` 目标：

- 在 `conformance` 通过的前提下
- 重新生成期望文件计划
- 对带 `// cde-tool:generated` marker 的文件做精确内容比对
- 报告缺失文件、多余 managed file、内容漂移
- v1 的 `exact` 仍是静态验证，不自动执行真实 SQLite / Core Data fetch 级运行时检查
- 当前已实现并接入 `cde-tool validate`
- `exact` 当前比较的是最终文本内容，而不是 AST / 语义等价
- 因此如果 formatter、linter 或其他工具会改写 tool-managed 文件，即使语义不变，也会被判定为 drift
- 使用 `exact` 时，必须让 tool-managed 文件跳过格式化与自动修复，或确保 generate 与 validate 看到的最终文本完全一致

`@Ignore` 规则：

- `@Ignore` 属性不参与模型对齐
- 代码中额外的 stored property 若未标记 `@Ignore`，视为 drift
- `@Ignore` 不得遮蔽模型中的持久化属性名
- `@Ignore` 不通过配置声明，必须从源码直接识别

自定义成员规则：

- `conformance` 允许在 `@PersistentModel` 类型中出现方法和计算属性，只要其余源码输入仍满足规则。
- `exact` 期望 tool-managed 文件保持 unchanged。
- 因此方法和计算属性应优先放在手写 extension 文件中，而不是直接修改生成文件。
- 当 validate 在类型本体中发现方法或计算属性时，会给出 `note`，提醒开发者将其移动到 extension 文件。
- `generate.emitExtensionStubs = true` 时，tool 会为每个实体创建一次 companion extension 示例文件，例如 `Item+Extensions.swift`。
- companion extension stub 不带 managed marker，只在文件缺失时创建，后续不会被覆盖或纳入 stale cleanup。

默认值规则：

- 默认存储的非 optional 持久化属性，代码默认值必须与模型默认值一致
- optional 持久化属性允许显式 `= nil`，也允许省略默认值
- 非 optional 的自定义 `raw` / `codable` / `composition` / `transformed` 仍按当前工具规则视为不合法
- v1 以“符合当前 tool 生成约定”为准，不尝试判断任意语义等价写法

autofix 边界：

- 当前 `validate` 会为一部分 diagnostics 附带 fix suggestion。
- 当前安全 autofix 只覆盖：
  - 缺失的 `@Relationship(inverse: ..., deleteRule: ...)`
  - `@Relationship` 中错误的 `inverse` / `deleteRule`
  - `@Attribute(...)` 中错误的 `persistentName` / `.unique` / `.transient`
  - `@Attribute(...)` 中错误的 `storageMethod` / `transformerType` / `decodeFailurePolicy`
  - 与模型 literal 完全不一致的直接默认值表达式
- 当前不会自动修复：
  - `@Ignore` 推断
  - broader rename
  - storage strategy 迁移
  - complex default-value expressions
  - composition 子路径展开

CLI 用法：

```bash
cde-tool validate --config cde-tool.json --fix
cde-tool validate --config cde-tool.json --fix --dry-run
```

composition 边界：

- 当前 `conformance` 只校验 composition 属性声明本身是否与规则一致
- 尚未校验 composition 的子路径/字段展开细节
- 这部分要等 tooling 配置真正描述 composition field mapping 后再补

`singleFile` 与 `exact`：

- `singleFile` 与 `exact` 在技术上可以共存。
- 但开发体验通常较差，因为所有实体的 managed 代码集中在一个文件里，自定义逻辑只能继续拆到外部文件。
- 长期使用 `exact` 时，更推荐：
  - `splitByEntity = true`
  - `emitExtensionStubs = true`
  - 并让 formatter/linter 忽略这些 tool-managed 文件

严重级别建议：

- `error`
  - entity / property / relationship 漂移
  - `persistentName` / `storageMethod` / `swiftType` 不一致
  - 默认值不一致
  - `@Ignore` 规则违规
  - exact 下的 managed file 内容漂移
- `warning`
  - 仅保留给建议性、非阻塞性提示；v1 应尽量少用

### 5.7 全局退出码约定（建议统一）

- `0`: 命令执行成功（包括 `validate` 无错误）。
- `1`: 业务层失败或用户输入错误（可通过修改参数/输入修复）。
- `2`: 运行时异常或内部错误（通常需要查看日志或修复实现）。

## 5.8 `inspect` 参数设计（当前实现）

- `--model-path <path>`
- `--model-version <name>`
- `--momc-bin <path>`
- `--config <path>`

约定：

- `inspect` 的 `--config` 读取 `generate` 节点，而不是 `validate` 节点。
- 原因是 inspect 需要反映生成侧的命名规则、类型映射和存储策略。
- 如果 `generate` 节点缺失，`inspect` 会报错。

## 6. 覆盖与安全策略（关键约定）

- 默认不覆盖（`overwrite=none`）。
- 只管理“带生成标记”的文件，避免误改手写代码。
- 生成文件统一放在独立目录（建议：`Generated/CoreDataEvolution`）。
- 关系到破坏性操作（`--clean-stale`）必须有明确提示，并限制在 `output-dir` 下。
- `dry-run` 输出应包含：
  - 将新增哪些文件。
  - 将修改哪些文件。
  - 将删除哪些文件（若启用 `clean-stale`）。

## 7. 漂移检测（Drift）建议规则

至少检查以下项：

- 实体是否一一对应。
- 属性名与 `persistentName` 映射是否一致。
- 默认类型映射是否符合 `typeMappings`。
- 属性级覆盖是否符合 `attributeRules`。
- 存储策略是否匹配（`default/raw/codable/composition/transformed`）。
- 关系方向、to-one/to-many、是否有序是否一致。
- composition 子路径映射（如 `location.x`）是否存在。

不直接检查的项：

- 宏展开后才存在的 `Keys`
- 宏展开后才存在的 `path`
- 宏展开后才存在的 `__cdFieldTable`

原因：

- 这三项不属于开发者源码输入
- 当前 validate 不观察宏展开产物
- validate v1 通过检查其输入声明来间接保证这些成员可被正确导出

## 8. 面向 SPM Plugin / GUI 的演进路径

- 抽出 `CoreEngine`（纯 Swift 库，无命令行依赖）。
- CLI 只负责参数解析、日志、exit code。
- SPM Plugin 复用 `CoreEngine`，把 target 信息转换成 CLI/Engine 参数。
- GUI 复用 `CoreEngine` 的 `inspect + generate + validate` API，显示差异视图。

## 9. v1 非目标（明确不做）

- 不做自动迁移推断（migration plan 自动生成）。
- 不做运行中数据库变更工具。
- 不做完整图形化编辑器。
- 不处理非 Core Data 模型来源（例如 YAML/JSON schema）。

## 10. 待拍板项（下一轮讨论）

- 生成文件命名规则（实体一文件 vs 功能分文件）。
- 是否默认生成“注释提示模板”（例如建议 init / count 用法）。
- `validate --exact` 是否要执行真实 SQLite 集成验证（速度 vs 可靠性）。
- 与现有宏测试快照体系的联动方式（是否生成 golden files）。
