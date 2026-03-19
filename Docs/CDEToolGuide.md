# cde-tool Guide

`cde-tool` is the companion CLI for `@PersistentModel`.

It is intentionally optional.

The package's core value does not depend on this tool:

- actor isolation via `@NSModelActor` / `@NSMainModelActor`
- macro-based model declarations via `@PersistentModel`

You can adopt those directly without bringing `cde-tool` into the project at all.

The CLI exists as a second layer for teams that want stronger workflow support, especially for:

- CI/CD drift detection
- config-driven generation and validation
- faster migration from existing Core Data projects

Its job is not to replace your model declarations. Its job is to keep the three layers of the
system aligned:

- the Core Data source model (`.xcdatamodeld` / `.xcdatamodel`)
- the Swift source you write with `@PersistentModel`
- the generated boilerplate that follows the package's rules

This guide explains:

- why the tool exists
- when you should use it
- how to choose between `generate`, `validate`, and `inspect`
- how `conformance` and `exact` validation differ
- how fix suggestions and safe autofix fit into validation
- how to build and use the CLI in practice

## Mental Model

`@PersistentModel` is a source-level representation of a Core Data model.

That source representation must stay aligned with the real Core Data schema. If it drifts, the
macro may still expand, but the model you are expressing is no longer the one you think you are
shipping.

`cde-tool` exists to make that alignment explicit.

Think of the tool as a schema companion:

- `generate` helps you create source that matches the model
- `validate` checks that existing source still matches the model
- `validate --fix` can apply a conservative subset of deterministic fixes
- `inspect` shows how the tool currently understands the model and rules
- `bootstrap-config` helps you create an editable project config from an existing model
- `init-config` gives you a default config template

The tool does not replace the macro system.

The macro system is responsible for expanding correct declarations into working code.

The tool is responsible for helping you:

- create those declarations
- keep them aligned over time
- detect drift before it turns into runtime or migration problems

That means the layering is deliberate:

- start with the macros if you only want the runtime/API improvements
- add `cde-tool` when you want workflow automation or CI/CD enforcement

## When You Need the Tool

You should use `cde-tool` when:

- you want to generate `@PersistentModel` source from an existing Core Data model
- your project has multiple entities and you want a repeatable model-to-source workflow
- you want CI to detect schema/source drift
- you want a stable config-driven setup for `persistentName`, storage methods, inverse hints, and
  validation rules

You may not need it if:

- you are only experimenting with a very small project
- you are writing the model declarations by hand once and do not need drift checking
- you are not using generated source files at all

For existing Core Data projects, `generate` is also a strong adoption tool.

It can quickly turn a legacy `.xcdatamodeld` into a usable `@PersistentModel` starting point,
similar in spirit to Xcode's model code generation, but aligned with CoreDataEvolution's rules and
macro surface.

That lowers the cost of getting from "this looks interesting" to "this runs in my project".

The bigger the model surface becomes, the more useful `cde-tool` becomes.

## What the Tool Accepts

`cde-tool` is intentionally source-model-only.

It accepts:

- `.xcdatamodeld`
- `.xcdatamodel`

It does not accept:

- `.momd`
- `.mom`

That restriction is deliberate. The CLI needs source-model information such as version selection and
Xcode code generation settings. Compiled model artifacts do not carry enough information for the
tooling workflow.

## Core Workflow

The normal workflow is:

1. start from a Core Data source model
2. create or refine a config
3. generate `@PersistentModel` source
4. add your own methods and computed properties outside the tool-managed files
5. validate drift as the model evolves

Typical first-time setup:

```bash
cde-tool bootstrap-config \
  --model-path Models/AppModel.xcdatamodeld \
  --output cde-tool.json
```

Then:

1. edit the generated config
2. run `generate`
3. add your hand-written extension files
4. run `validate`

If validate reports only deterministic annotation or literal drift, you can optionally apply safe
fixes:

```bash
swift run --skip-build cde-tool validate --config cde-tool.json --fix
```

Or preview those edits without writing files:

```bash
swift run --skip-build cde-tool validate --config cde-tool.json --fix --dry-run
```

## Building the CLI

For normal development, you can use:

```bash
swift run --skip-build cde-tool --help
```

If you want a reusable local binary, use:

```bash
bash Scripts/build-cde-tool.sh
```

This script:

- builds `cde-tool` in release mode
- injects version metadata when git metadata is available
- prints the final binary path

You can also copy the binary to a local tools directory:

```bash
bash Scripts/build-cde-tool.sh --copy-to ~/bin
```

If a binary already exists there:

```bash
bash Scripts/build-cde-tool.sh --copy-to ~/bin --force
```

## Checking the Tool Version

Three version entry points are available:

```bash
cde-tool --version
cde-tool -v
cde-tool version
```

Use them as follows:

- `--version`
  - concise output, suitable for scripts
- `-v`
  - detailed build metadata
- `version`
  - same detailed metadata, explicit command form

This matters because `cde-tool` is intentionally coupled to the library and macro semantics.

When debugging a report or CI failure, always check the tool version first.

### Local Version Behavior

The local version behavior is intentionally simple:

- if you build from a git checkout, the tool can report:
  - version
  - tag
  - commit
  - describe
  - dirty
- if you build from a source archive without git metadata, the tool falls back to development
  metadata

That means:

- local source builds are still usable
- release-quality provenance should come from the release pipeline, not from ad hoc local archives

## Release Strategy

The current release strategy is split into two layers.

### Local / Development Builds

For local builds, the tool keeps the fallback mechanism:

- `cde-tool --version`
  - concise version string
- `cde-tool -v`
  - version
  - tag
  - commit
  - describe
  - dirty
- `cde-tool version`
  - same detailed metadata as `-v`

This is enough for:

- local debugging
- issue reports
- CI logs in repository builds

### GitHub Release Builds

For release artifacts, the intended path is GitHub Actions.

When building from a release tag, the workflow should:

1. build the `cde-tool` binary
2. generate `version.json`
3. generate checksums
4. upload the release assets

That keeps the release artifacts fully traceable even when users download binaries or source
archives outside a git checkout.

## Config Files

The CLI supports JSON config files so you do not need to repeat long argument lists.

Quick distinction:

- `init-config`
  - skeleton-only
  - does not read a model
- `bootstrap-config`
  - model-driven
  - requires a real Core Data source model

Create a default template:

```bash
cde-tool init-config --output cde-tool.json
```

Or print it directly:

```bash
cde-tool init-config --stdout
```

When using config files:

- `generate` reads the `generate` section
- `validate` reads the `validate` section
- `inspect --config` reads the `generate` section

Relative paths are resolved from the config file's directory.

That is true for:

- `modelPath`
- `momcBin`
- output/source directories
- header template paths

## Editing `cde-tool.json`

In practice, most manual edits fall into three buckets:

- rename the Swift-facing property while keeping the Core Data persistent name stable
- choose the Swift type and storage method for a field
- rename the Swift-facing relationship property while keeping the Core Data relationship name stable

The important thing to remember is that config rules are keyed by the **persistent model name**,
not by the generated Swift name.

That means:

- `attributeRules.<Entity>.<persistentAttributeName>`
- `relationshipRules.<Entity>.<persistentRelationshipName>`

If you use both `generate` and `validate`, keep these rule blocks aligned in both sections.

### Rename a Swift property but keep the persistent field name

Use `attributeRules` when the Core Data model should keep one field name, but the generated Swift
property should use another.

Example:

```json
{
  "generate": {
    "attributeRules": {
      "Item": {
        "name": {
          "swiftName": "title"
        }
      }
    }
  }
}
```

Here:

- Core Data persistent field name: `name`
- generated Swift property name: `title`
- generated macro annotation: `@Attribute(persistentName: "name") var title: String ...`

The key `name` is the persistent field from the model. It is **not** the Swift property name.

### Rename a Swift relationship property but keep the persistent relationship name

Use `relationshipRules` the same way for relationships.

Example:

```json
{
  "generate": {
    "relationshipRules": {
      "Item": {
        "primary_category": {
          "swiftName": "category"
        }
      }
    }
  }
}
```

Here:

- Core Data persistent relationship name: `primary_category`
- generated Swift property name: `category`

The generated `@Relationship(...)` annotation still uses the persistent relationship name from the
model. The config only changes the Swift-facing property name.

### Choose the Swift type and storage method for a field

Use `attributeRules` when a field should not stay as the default primitive mapping.

Common examples:

- enum-backed raw storage
- `Codable` payload storage
- `ValueTransformer`-backed storage

#### `.raw`

```json
{
  "generate": {
    "attributeRules": {
      "Item": {
        "status_raw": {
          "swiftName": "status",
          "swiftType": "ItemStatus",
          "storageMethod": "raw"
        }
      }
    }
  }
}
```

Use this when the model stores a primitive field, but the Swift API should expose a
`RawRepresentable` type such as an enum.

#### `.codable`

```json
{
  "generate": {
    "attributeRules": {
      "Item": {
        "config_blob": {
          "swiftName": "config",
          "swiftType": "ItemConfig",
          "storageMethod": "codable"
        }
      }
    }
  }
}
```

Use this when the model stores an encoded payload but the Swift API should expose a Codable value
type.

#### `.transformed`

```json
{
  "generate": {
    "attributeRules": {
      "Item": {
        "keywords_payload": {
          "swiftName": "keywords",
          "swiftType": "[String]",
          "storageMethod": "transformed",
          "transformerName": "NSSecureUnarchiveFromData"
        }
      }
    }
  }
}
```

For transformed storage:

- `storageMethod` must be `"transformed"`
- the Core Data field must be modeled as `Transformable`
- `transformerName` is required
- `swiftType` should be the Swift-facing property type you want the generated source to use

### Change the default Swift type for one Core Data primitive kind

Use `typeMappings` when you want to change the default Swift type chosen for a Core Data primitive
kind across the config section.

Example:

```json
{
  "generate": {
    "typeMappings": {
      "Integer 64": {
        "swiftType": "Int"
      }
    }
  }
}
```

This changes the default mapping for all `Integer 64` fields in that section unless a more
specific per-field `attributeRules` override is present.

Use `typeMappings` for broad defaults, and `attributeRules` for one-off exceptions.

### Practical advice

- Start with `bootstrap-config --style explicit` if you want a manifest you can review and edit in
  one place.
- Use `inspect` before and after a config change when you want to confirm how the tool resolved a
  field or relationship.
- Prefer editing one entity at a time, then run `generate` or `validate` immediately.
- When a field uses `raw`, `codable`, `composition`, or `transformed`, set `swiftType`
  explicitly so the tool does not have to infer it.

## Validate Fix Suggestions

`validate` diagnostics can carry fix suggestions.

These suggestions are model-derived. They are intended to show:

- what source shape the tool expects
- whether the mismatch is deterministic enough to rewrite automatically
- which edits belong to the safe autofix set

Safe autofix currently targets only cases that the tool can rewrite without guessing, such as:

- inserting a missing `@Relationship(inverse: ..., deleteRule: ...)`
- correcting `inverse` or `deleteRule` inside an existing `@Relationship`
- correcting `@Attribute(...)` metadata such as `persistentName`, `.unique`, `.transient`,
  `storageMethod`, transformer type, or decode failure policy
- correcting a direct default-value literal when the model already defines the expected literal

Autofix intentionally does **not** rewrite higher-risk cases such as:

- broader renames that would require updates outside the property declaration
- `@Ignore` inference
- storage-strategy migrations that need developer review
- complex default-value expressions that are not already represented as a direct literal

This keeps `--fix` conservative. The tool only rewrites what it can determine from the model and
current generation rules without introducing new assumptions.

## `generate`

`generate` turns a Core Data source model plus rules into `@PersistentModel` source files.

Example:

```bash
cde-tool generate \
  --config cde-tool.json
```

Or direct arguments:

```bash
cde-tool generate \
  --model-path Models/AppModel.xcdatamodeld \
  --output-dir Sources/AppModels \
  --module-name AppModels
```

Use `generate` when:

- you are creating source for the first time
- the model changed and you want the source regenerated
- you want tool-managed files to follow current naming and storage rules

Useful flags:

- `--dry-run true`
  - show planned writes without touching disk
- `--single-file true`
  - emit one managed file
- `--split-by-entity true`
  - emit one managed file per entity
- `--emit-extension-stubs true`
  - create companion extension files for hand-written methods and computed properties

## `validate`

`validate` checks whether the current source still matches the model and the configured rules.

Example:

```bash
cde-tool validate --config cde-tool.json
```

Or:

```bash
cde-tool validate \
  --model-path Models/AppModel.xcdatamodeld \
  --source-dir Sources/AppModels \
  --module-name AppModels
```

The tool supports two validation modes:

- `conformance`
- `exact`

### `conformance`

`conformance` checks rules.

It validates whether the source written by the developer still conforms to:

- the Core Data model
- the configured naming and storage rules
- the package's `@PersistentModel` constraints

This mode does **not** require tool-managed files to be byte-for-byte identical to the current
generator output.

Use `conformance` when:

- developers may make limited source-level adjustments
- you care about correctness more than exact generated text
- generated files may still pass through normal project tooling

### `exact`

`exact` checks unchanged generated output.

It first performs `conformance`, then additionally verifies that tool-managed files match the
current generator output exactly.

`exact` does not compile downstream generated targets for you.

It is a source/output consistency check, not a guarantee that another package target consuming the
generated files has been compiled successfully. If your workflow depends on generated models being
buildable as a separate target, keep an explicit `swift build` step in CI or local verification.

That means:

- managed file paths must match
- managed file contents must match
- stale managed files are reported
- hand-edited managed files are reported

Use `exact` when:

- you want CI to enforce a no-drift rule
- generated files are treated as read-only artifacts
- your team wants regeneration to be the only way managed files change

### Important Notes for `exact`

`exact` is intentionally strict.

Do not use it as the default mental model for every project.

If you adopt `exact`, you must also adopt its constraints:

- do not hand-edit tool-managed files
- do not run formatters or auto-fixers over tool-managed files
- do not let lint tools rewrite whitespace or imports in tool-managed files

If formatting changes the managed file text, `exact` will report drift even when semantics did not
change.

## Best Practice: Put Custom Code in Separate Extensions

This is the recommended pattern:

- let `cde-tool` own the managed file
- put your custom methods in a separate extension file
- put your computed properties in a separate extension file

Example:

```swift
// Sources/AppModels/Item+Extensions.swift

extension Item {
  var displayTitle: String {
    title.uppercased()
  }

  func markAsRead() {
    isRead = true
  }
}
```

This matters especially in `exact` mode.

If you add methods or computed properties directly into a tool-managed file, the next exact
validation will report drift.

If you use:

```bash
--emit-extension-stubs true
```

the generator will create companion extension files to make this pattern obvious from the start.

## `inspect`

`inspect` is a debugging command.

It loads the model and resolved rules, then prints the intermediate representation (IR) as JSON.

Example:

```bash
cde-tool inspect \
  --model-path Models/AppModel.xcdatamodeld
```

Or with config:

```bash
cde-tool inspect \
  --model-path Models/AppModel.xcdatamodeld \
  --config cde-tool.json
```

`--config` can supply generation rules, but `inspect` still requires `--model-path`.

Use `inspect` when:

- you want to see how the tool currently resolves attribute names
- you want to check storage methods and inverse hints
- you are debugging config rules or generation behavior

This command is especially useful before changing config or when a generate/validate result looks
surprising.

## `bootstrap-config`

`bootstrap-config` creates an editable config scaffold from a real model.

By default it emits a compact scaffold. That keeps the first draft focused on the rules and
placeholders you are most likely to edit first.

Example:

```bash
cde-tool bootstrap-config \
  --model-path Models/AppModel.xcdatamodeld \
  --output cde-tool.json
```

If you want a complete manifest that also writes the current default mappings explicitly, use:

```bash
cde-tool bootstrap-config \
  --model-path Models/AppModel.xcdatamodeld \
  --style explicit \
  --output cde-tool.json
```

Use it when:

- you are adopting `cde-tool` in an existing project
- you want a starting point for `typeMappings` and `attributeRules`
- you want generate and validate to share one explicit rule set

Use `--style explicit` when:

- you want to review every attribute, relationship, and composition mapping in one file
- you want to hand-edit a full config instead of only the non-default parts
- you want a round-trippable manifest that makes the tool's current defaults visible

The generated config is meant to be edited.

It is not a final answer; it is a starting point.

## `init-config`

`init-config` creates a default JSON template without reading a model.

Use it when:

- you want a clean config skeleton
- you already know the structure you want
- you do not need a model-driven scaffold

Examples:

```bash
cde-tool init-config --output cde-tool.json
cde-tool init-config --output cde-tool.json --preset minimal
cde-tool init-config --output cde-tool.json --force
cde-tool init-config --stdout
```

Useful options:

- `--preset minimal`
  - emit a smaller starter template
- `--preset full`
  - emit the full template; this is the default
- `--force`
  - overwrite an existing config file when writing to disk

## What the Tool Does Not Do

The tool does not:

- replace macro expansion
- validate macro-expanded implementation details directly
- accept compiled `.mom` / `.momd` as the main workflow input
- make generated files safe to hand-edit under `exact`

It also does not remove the need to understand the model rules from
[PersistentModelGuide.md](./PersistentModelGuide.md).

The CLI works because those rules are intentionally strict and tooling-friendly.

## Recommended Team Workflow

For a team project, the most stable approach is:

1. keep the Core Data source model as the schema source of truth
2. keep `cde-tool.json` in the repository
3. generate source from the tool, not by hand-copying patterns
4. put custom behavior in extension files
5. use `conformance` locally
6. use `exact` in CI only if your team is ready to treat managed files as read-only

That gives you:

- clear ownership of generated files
- explicit config-driven rules
- predictable review diffs
- earlier drift detection

## Related Guides

- [PersistentModelGuide.md](./PersistentModelGuide.md)
- [StorageMethodGuide.md](./StorageMethodGuide.md)
- [TypedPathGuide.md](./TypedPathGuide.md)
