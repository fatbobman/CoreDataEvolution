# Contributing

Thanks for helping improve CoreDataEvolution. This project modernizes Core Data usage through Swift
macros, actor isolation, typed paths, Observation support, and tooling. Contributions should keep
that scope clear and preserve the package's broad platform compatibility.

## Before You Start

- Check existing issues or task records before opening overlapping work.
- Keep changes focused on one concern: runtime behavior, macros, tooling, generated output, tests,
  or documentation.
- Do not add APIs that require iOS 17+ or macOS 14+ unless they are guarded by explicit availability
  checks.
- For user-facing documentation, use English unless a development note is intentionally internal.

## Local Setup

Use a Swift 6 toolchain. The package baseline supports:

- iOS 13.0+
- macOS 10.15+
- tvOS 13.0+
- watchOS 6.0+
- visionOS 1.0+

Start with:

```bash
swift build
bash Scripts/run-tests.sh
```

`Scripts/run-tests.sh` wraps `swift test` and enables Core Data concurrency checking for local CLI
runs. Prefer it over bare `swift test` when validating behavior.

## Useful Validation Commands

For focused test runs:

```bash
bash Scripts/run-tests.sh --filter NSModelActorTests
bash Scripts/run-tests.sh --filter WithContextTests
bash Scripts/run-tests.sh --filter IntegrationModel
```

For generated-model and tooling changes:

```bash
bash Scripts/build-cde-tool.sh
bash Scripts/compile-integration-model.sh
bash Scripts/test-integration-model.sh
bash Scripts/test-generated-flow.sh
```

For docs-only or task-record-only changes:

```bash
node Scripts/task-index.mjs validate
git diff --check
git diff --name-only -- '*.swift'
```

## Formatting

Swift files use the repository's `.swift-format` settings:

- 2-space indentation
- 100-column line length
- ordered imports
- ASCII identifiers

If `swift-format` is installed, run it on changed Swift files:

```bash
swift-format format --in-place <path-to-file.swift>
```

The repository also includes an optional pre-commit hook under `.githooks/`.

## Pull Requests

Please include:

- the user-facing problem or maintenance gap being addressed
- the changed package area
- tests or validation commands run
- documentation updates, if public behavior changed
- release notes impact, if users need to take action

Macro, tooling, and Core Data concurrency changes should include focused tests whenever practical.
Documentation-only changes should still pass whitespace and task-record validation where relevant.

## Security Reports

Do not post sensitive security details in public issues. Follow [SECURITY.md](./SECURITY.md) for the
security reporting path.
