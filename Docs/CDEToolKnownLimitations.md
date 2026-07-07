# cde-tool Known Limitations

This page describes the current `cde-tool` v1 boundaries.

These limitations are not bugs by themselves, and they are not roadmap promises. They are the
behavioral edges you should understand before using the tool in CI or in a generated-source
workflow.

## Model Inputs

`cde-tool` works from Core Data source models:

- `.xcdatamodeld`
- `.xcdatamodel`

It does not use compiled `.mom` or `.momd` artifacts as workflow inputs. Source models preserve
version-selection and code-generation metadata that compiled artifacts do not provide.

The tool also rejects Derived Attributes. Supporting them would require separate generation,
validation, and documentation rules.

## Bootstrap And Config Inference

`bootstrap-config` creates an editable starting point, not a finished project policy.

It does not infer:

- enum or raw-value candidates
- composition candidates
- domain-specific property renames
- custom semantic mappings that are not explicit in the Core Data model

`bootstrap-config --style explicit` expands known default mappings, but it still does not invent
higher-level rules. Review the generated config before using it in generation or validation.

`generate.attributeRules` and `validate.attributeRules` are separate config sections. If a project
uses both commands, keep the relevant rules aligned in both sections.

## Generate Boundaries

`generate` only creates source that can be derived from the model and config.

It does not infer `@Ignore` properties or pure in-memory fields from information outside the model.
There is no separate config model today for describing additional `@Ignore` stored properties that
should be generated into tool-managed files.

For default values, the generator uses the model defaults it can represent directly. It does not
provide a separate code-default override for non-optional custom Codable, composition, transformed,
or raw-value types.

## Validate Boundaries

`validate` checks source declarations against the model and config rules.

It assumes the package macros expand correctly. It does not directly validate macro-generated
members such as:

- `Keys`
- `path`
- `__cdFieldTable`

That makes `validate` a source/model/config alignment check, not a replacement for package tests or
downstream build checks.

Composition validation currently checks the property declaration shape. It does not validate every
composition subpath or field-expansion detail.

Validation follows the tool's current generation conventions. It does not try to prove that every
possible Swift expression is semantically equivalent to a model default.

## Exact Mode Boundaries

`exact` mode is a text-level generated-output drift check.

It is useful when tool-managed files are treated as generated artifacts, but it has strict
operational expectations:

- do not hand-edit managed files
- keep custom code in separate extension files
- make formatters and linters ignore managed files, or accept that formatting can create drift

`exact` can technically run with `singleFile`, but the day-to-day workflow is usually clearer with
`splitByEntity` plus `emitExtensionStubs`.

`conformance` mode can allow extra `@Ignore` stored properties, but `exact` compares managed files
against generated output. Extra hand-written stored properties in a managed file will therefore be
reported as drift.

## Inspect And Diagnostics

`inspect` is a debugging command. It reports how the tool resolves the model and config into an
intermediate representation.

When it encounters unresolved fields, it reports diagnostics for inspection. It is not a strict
replacement for `generate` or `validate`.

## Safe Autofix Boundaries

`validate --fix` only applies deterministic text edits.

It does not automatically rewrite:

- broad renames that may affect call sites
- `@Ignore` inference
- storage-strategy migrations
- complex default-value expressions
- changes that require project-specific judgment

Those cases remain diagnostics so the developer can make the decision explicitly.

## Recommended Handling

Use these boundaries as workflow constraints:

- start from `bootstrap-config`, then review and edit the config
- use `inspect` to understand how rules resolve
- prefer `conformance` while source is still actively edited
- use `exact` only when managed files are treated as generated artifacts
- keep downstream build or test steps in CI when generated source must compile as part of a package

See [CDEToolGuide.md](./CDEToolGuide.md) for the main workflow guide.
