# Generated Flow Testing

This document defines the repository-local generated-flow integration used for the next round of
black-box style validation.

## Purpose

The normal unit, macro, and tooling tests are necessary but not sufficient.

They do not fully exercise the external consumption path where:

1. `cde-tool generate` writes source into another package target
2. that package builds a public generated-model module
3. another target imports that module and uses typed-path APIs
4. the generated models run against a real compiled `.xcdatamodeld`

This flow is where earlier issues surfaced:

- redundant generated conformances
- public typed-path visibility regressions across targets
- generated-source shapes that passed `validate --level exact` but still failed real compilation
- schema-backed composition mismatches

The generated-flow fixture exists to catch those issues earlier inside this repository.

## Fixture Layout

The fixture package lives at:

- `Integration/GeneratedFlowFixture/`

It contains:

- `Package.swift`
  - a separate SwiftPM package that depends on this repository by local path
- `Models/GeneratedFlowModel.xcdatamodeld`
  - the source model used by `cde-tool`
- `Sources/GeneratedModels/`
  - handwritten support types plus tool-generated model source
- `Sources/GeneratedFlowApp/`
  - a real executable target that imports `GeneratedModels`, compiles the source model, creates a
    container, saves data, and queries through generated typed paths
- `cde-tool.json`
  - the generate/validate config used by the fixture

## What This Flow Covers

The fixture is intentionally designed to cover the user-facing paths that are most likely to drift:

- public generated models consumed from another target
- renamed attributes via `persistentName`
- explicit relationship metadata via `@Relationship(...)`
- renamed relationships via tooling `relationshipRules`
- raw-value storage
- codable storage
- transformed optional collection storage
- schema-backed composition using a real Core Data composite attribute
- chained typed paths, including:
  - `FlowTask.path.title`
  - `FlowTask.path.project.name`
  - `FlowTask.path.location.latitude`

## Standard Command

Run the full generated-flow integration with:

```bash
bash Scripts/test-generated-flow.sh
```

The script performs these steps in order:

1. build `cde-tool`
2. generate source into `Integration/GeneratedFlowFixture/Sources/GeneratedModels`
3. validate the generated source in both `conformance` and `exact` modes
4. remove the fixture package's local `.build` directory so macro expansions are rebuilt from the
   current repository state
5. build the external executable target
6. run the executable smoke flow

A passing run means:

- `cde-tool generate` produced usable source for an external package target
- `validate` accepted the generated source in both supported modes
- the external package compiled successfully
- the executable completed a real save/query round-trip against a compiled Core Data model

The script intentionally removes `Integration/GeneratedFlowFixture/.build` before rebuilding the
fixture target. This keeps the black-box flow honest when macro implementations change but the
generated source files themselves do not.

## Useful Variants

Skip generation if you want to inspect or hand-edit the fixture first:

```bash
bash Scripts/test-generated-flow.sh --skip-generate
```

Skip validation if the current investigation is only about compile/runtime behavior:

```bash
bash Scripts/test-generated-flow.sh --skip-validate
```

Skip the executable build phase:

```bash
bash Scripts/test-generated-flow.sh --skip-build
```

Skip the runtime smoke run while still compiling the external target:

```bash
bash Scripts/test-generated-flow.sh --skip-run
```

## Environment Overrides

The script supports a small set of environment overrides for local experiments:

- `CDE_GENERATED_FLOW_FIXTURE`
  - alternate fixture package path
- `CDE_GENERATED_FLOW_CONFIG`
  - alternate config path
- `CDE_GENERATED_FLOW_TARGET`
  - alternate executable target name

Example:

```bash
CDE_GENERATED_FLOW_TARGET=GeneratedFlowApp bash Scripts/test-generated-flow.sh
```

## Interpreting Failures

Use this split when triaging failures.

### Generate succeeds, `validate` succeeds, external build fails

This is a generated-source usability problem.

Typical examples:

- access control not exported correctly across targets
- generated declarations that compile inside repository-local tests but fail in a true consumer
- macro/compiler interaction issues only triggered by the external package build graph

### External build succeeds, runtime smoke fails

This is usually one of:

- model-side setup mismatch
- generated accessor/runtime contract mismatch
- unsupported modeling assumption that needs clearer validation or documentation

### `exact` succeeds but build still fails

This does **not** mean `exact` is wrong.

`exact` checks:

- source-rule conformance
- tool-managed file consistency against current tool output

It does **not** compile downstream consumer targets.

That is why this generated-flow fixture exists as a separate integration layer.

## How To Use This In Future Black-Box Rounds

For a new black-box test round:

1. run `bash Scripts/test-generated-flow.sh`
2. if it fails, reduce the failure to the smallest reproducible fixture change
3. fix the library/tooling in this repository
4. keep or expand the fixture so the bug becomes part of the standard regression path

This flow should be treated as the repository's closest approximation of a real downstream consumer.
