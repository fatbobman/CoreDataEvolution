# CoreDataEvolution — Agent Guide

This file is for agents working in this repository. Keep it focused on workflow, constraints, and repo-specific pitfalls. Detailed API usage already lives in `README.md`.

## Project Summary

CoreDataEvolution brings SwiftData-style actor isolation to Core Data through macros and a custom serial executor.

- Library target: `CoreDataEvolution`
- Macro target: `CoreDataEvolutionMacros`
- Example executable: `CoreDataEvolutionClient`
- Test target: `CoreDataEvolutionTests`

The package uses Swift 6 and ships a macro implementation backed by `swift-syntax`. `swift-syntax` is a build-time dependency only.

## Platform And Toolchain Constraints

- Minimum deployment targets are iOS 13, macOS 10.15, tvOS 13, watchOS 6, visionOS 1.
- Use Swift 6 language mode.
- Do not introduce APIs that require iOS 17+ / macOS 14+ unless guarded by explicit availability checks.
- The runtime executor implementation must remain compatible with the minimum deployment targets.

## Repository Layout

Public root-level user docs:

- `README.md`: primary user-facing overview.
- `AGENTS.md`: repository workflow and contributor guidance.

User-facing supplemental docs live under `Docs/`.

Internal development docs live under `Docs/Development/`.


- `Package.swift`: package definition, product graph, platform constraints, Swift settings.
- `Sources/CoreDataEvolution`: public library code.
- `Sources/CoreDataEvolutionMacros`: macro expansion code.
- `Sources/CoreDataEvolutionClient`: minimal example executable.
- `Tests/CoreDataEvolutionTests`: package tests plus helper Core Data model types.
- `.githooks`: optional git hooks for formatting staged Swift files before commit.
- `.swift-format`: formatting rules used by the hook and local formatting runs.

## Build And Test Commands

Use these first:

```bash
swift build
swift test
```

Useful targeted runs:

```bash
swift test --filter NSModelActorTests
swift test --filter WithContextTests
swift test --filter IntegrationModel
```

Formatting, if `swift-format` is installed:

```bash
swift-format format --in-place <path-to-file.swift>
```

Integration model compile + run (for real `.momd` verification):

```bash
bash Scripts/compile-integration-model.sh
bash Scripts/test-integration-model.sh
```

Path/toolchain behavior for integration model scripts:

- Do not hardcode toolchain paths. `Scripts/compile-integration-model.sh` resolves `momc` in this order:
  1. `CDE_MOMC_BIN`
  2. `xcrun --find momc`
  3. `momc` from `$PATH`
- Model source can be overridden by `CDE_INTEGRATION_MODEL_SOURCE`.
- Output `.momd` can be overridden by `CDE_INTEGRATION_MODEL_OUTPUT`.
- Tests can consume a precompiled model via `CDE_INTEGRATION_MODEL_MOMD`.
- If `CDE_INTEGRATION_MODEL_MOMD` is not set, integration tests compile the model on demand via `Scripts/compile-integration-model.sh`.

## Release Tag Convention

- Release tags use bare semantic versions in the form `x.y.z`.
- Do not prefix release tags with `v`.
- Follow the existing repository convention, for example `0.7.4`.

## Git Hooks And Formatting

This repo includes an optional pre-commit hook.

- Install with `bash .githooks/install.sh`, or set `git config core.hooksPath .githooks`.
- The hook formats staged `.swift` files and re-stages them.
- If `swift-format` is missing, the hook warns and exits successfully. It does not block commits.
- `swift-format` is resolved from `$PATH`, then `~/.swiftly/bin/swift-format`, then `xcrun --find swift-format`.

When editing Swift files, keep formatting consistent with `.swift-format`:

- 2-space indentation
- 100-column line length
- ordered imports
- ASCII identifiers only

## Architecture Notes

### Public library target

`Sources/CoreDataEvolution` contains:

- `Macros.swift`: public macro declarations.
- `NSModelActor.swift`: actor protocol plus `unownedExecutor`, `modelContext`, typed subscript, and `withContext` helpers.
- `NSMainModelActor.swift`: main-actor class protocol plus `modelContext`, typed subscript, and `withContext` helpers.
- `NSModelObjectContextExecutor.swift`: serial executor that enqueues `UnownedJob` on `NSManagedObjectContext.perform`.
- `NSPersistentContainer+Testing.swift`: isolated SQLite-backed test container helper.
- `module.swift`: re-exports `CoreData`.

### Macro target

`Sources/CoreDataEvolutionMacros` is intentionally small:

- `NSModelActorMacro` adds `modelExecutor`, `modelContainer`, and optionally `init(container:)`, then adds `NSModelActor` conformance.
- `NSMainModelActorMacro` adds `modelContainer` and optionally `init(modelContainer:)`, then adds `NSMainModelActor` conformance.
- `Helper.swift` contains the shared parsing helpers for `disableGenerateInit` and access control.

The macros currently mirror `public` access from the attached type, but otherwise do very little validation. If you add validation or diagnostics, update tests and docs accordingly.

## Behavior That Must Stay True

- `@NSModelActor` default initializer uses `container.newBackgroundContext()`.
- `@NSMainModelActor` binds `modelContext` to `container.viewContext`.
- `@NSMainModelActor` types are expected to be `@MainActor` classes. The macro does not currently enforce this itself.
- `disableGenerateInit: true` means the custom initializer must assign the generated stored properties correctly.
- `NSModelObjectContextExecutor` is `@unchecked Sendable`; changes here are concurrency-sensitive and need careful review.
- `module.swift` intentionally uses `@_exported import CoreData`; avoid removing it without checking downstream API impact.

## Test Requirements And Pitfalls

The tests encode several important constraints. Preserve them.

- Use `NSPersistentContainer.makeTest(...)` for test stores.
- Do not use `/dev/null` as a Core Data store URL. This repo explicitly avoids it because parallel tests can share state and deadlock.
- `makeTest` uses an on-disk SQLite store under a temp subdirectory and deletes stale `.sqlite`, `.sqlite-shm`, and `.sqlite-wal` files before loading.
- `makeTest` intentionally serializes `NSPersistentContainer` creation and `loadPersistentStores` with a global lock.
- Reason: under extreme parallel test execution, Core Data can crash inside `loadPersistentStores` with `EXC_BAD_ACCESS` or hang, even when every test uses a unique SQLite store URL.
- The motivating real-world case came from `PersistentHistoryTrackingKit`: many Core Data-heavy tests running in one process, shared static model/container helpers, and parallel container creation. Without the lock the suite had to run serially; with the lock, the tests could run in parallel again.
- Do not remove that lock unless the container initialization path is reworked and revalidated under repeated parallel stress runs.
- `testName` defaults to call-site identity via `#fileID` and `#function`. That isolation is intentional.
- Test model definitions should use `static let` for `NSManagedObjectModel`; multiple model instances for the same schema can break store registration.
- Test helper files use `@preconcurrency import CoreData` to suppress Swift 6 sendability noise around Core Data types.
- `TestStack` sets `container.viewContext.automaticallyMergesChangesFromParent = true`; keep that in mind when changing tests involving background writes.
- Main-thread tests are explicitly marked `@MainActor`.
- For tests that verify real persistence behavior, prefer suite-local `@NSModelActor` handlers over directly manipulating contexts in test functions.
- If a test needs direct context/container access for assertions, use `try await handler.withContext { ... }` so operations stay in the actor isolation domain.
- Use `@MainActor` test suites only when the behavior under test is explicitly main-actor/viewContext specific.

## Test Plan

`Tests/CoreDataEvolutionTests/CoreDataEvolution-Package.xctestplan` enables:

```text
-com.apple.CoreData.ConcurrencyDebug 1
```

This is useful when running the package tests through Xcode with the test plan. Do not assume plain `swift test` will automatically pick up the same runtime argument.

## Implementation Guidance

When making code changes:

- Check both the library target and the macro target. Many user-facing changes require edits in both.
- If you change generated members or initializer behavior, update tests first or in the same change.
- If you change public macro semantics, update `README.md` and DocC as well.
- Keep main-actor and background-actor behavior aligned where appropriate; the two protocol extensions intentionally expose similar APIs.
- Be conservative around availability, executor behavior, and Core Data threading assumptions.

## ToolingCore Comment Standard

When editing `Sources/CoreDataEvolutionToolingCore/`:

- Add succinct comments to public types and service entry points so another developer can quickly understand the role of each file and API.
- Add short internal comments only where a helper encodes non-obvious behavior, ordering, or fallback rules.
- Do not comment every line. Prefer comments that explain:
  - what problem a type/function solves
  - which inputs or precedence rules matter
  - which assumptions or v1 boundaries are intentional
- Keep comments aligned with code and docs. If behavior changes, update the nearby comment in the same change.

## Current WIP (TypedPath)

There is active WIP for typed path mapping and NSPredicate construction.

- Source location: `Sources/CoreDataEvolution/TypedPath/`
- Test location: `Tests/CoreDataEvolutionTests/TypedPath/`
- Purpose: support `Keys + path + __cdFieldTable` as the shared base for sort and `%K`-based predicate building.

Current scope:

- Typed sort construction from `Object.Keys` and `Object.path.*`
- `%K` predicate building from mapped paths (including composition and relationships)
- To-many predicate quantifiers: `any` / `all` / `none`
- Composition contracts via `CDCompositionPathProviding` + `CDCompositionValueCodable` (no runtime reflection)
- `@Composition` currently generates:
  - `__cdCompositionFieldTable`
  - `__cdDecodeComposition(from:)`
  - `__cdEncodeComposition`

Current boundaries:

- Sort does **not** support to-many relationship paths.
- Predicate layer currently stays on Foundation `NSPredicate` (no separate `CDPredicate` type).
- `.none` and `.all` are expanded using `NOT (ANY ...)` forms for compatibility.

When editing this area:

- Keep mapping key space anchored to Swift paths in `__cdFieldTable`.
- Keep `%K` as the only key interpolation path for predicate format strings.
- Update both docs (`Docs/Development/Specification.md`, `Docs/Development/ImplementationPlan.md`, `Docs/Development/DesignNotes.md`) and tests together.

## Macro Test Skeleton (Recommended)

Before implementing new macros or changing generated members, set up macro tests first to prevent silent expansion drift.

Recommended structure:

- `Tests/CoreDataEvolutionMacroTests/`
- `Tests/CoreDataEvolutionMacroTests/MacroTestSupport.swift`
- `Tests/CoreDataEvolutionMacroTests/MacroExpansionSnapshotTests.swift`
- `Tests/CoreDataEvolutionMacroTests/MacroDiagnosticTests.swift`
- `Tests/CoreDataEvolutionMacroTests/Fixtures/`
- `Tests/CoreDataEvolutionMacroTests/__Snapshots__/`

Recommended workflow:

1. Use snapshot tests for expanded source output.
2. Use diagnostic tests for compile-time errors/warnings messages.
3. Gate snapshot updates behind `UPDATE_SNAPSHOTS=1`; default CI behavior should fail on mismatch.

Implementation notes:

- Prefer using the same `SwiftSyntax` expansion pipeline pattern as `ObservableDefaultsMacroTests` (`SwiftParser` + `SwiftSyntaxMacroExpansion` + `BasicMacroExpansionContext`).
- Keep one shared macro registry in `MacroTestSupport` for all test files.
- When macro output changes intentionally, update snapshots and docs in the same change.

## Files Worth Reading Before Nontrivial Changes

- `Package.swift`
- `Sources/CoreDataEvolution/Macros.swift`
- `Sources/CoreDataEvolution/NSModelActor.swift`
- `Sources/CoreDataEvolution/NSMainModelActor.swift`
- `Sources/CoreDataEvolution/NSModelObjectContextExecutor.swift`
- `Sources/CoreDataEvolution/NSPersistentContainer+Testing.swift`
- `Sources/CoreDataEvolutionMacros/NSModelActorMacro.swift`
- `Sources/CoreDataEvolutionMacros/NSMainModelActorMacro.swift`
- `Tests/CoreDataEvolutionTests/NSModelActorTests.swift`
- `Tests/CoreDataEvolutionTests/WithContextTests.swift`
- `Tests/CoreDataEvolutionTests/Helper/Container.swift`
- `Sources/CoreDataEvolution/TypedPath/`
- `Tests/CoreDataEvolutionTests/TypedPath/`

## Documentation Scope

Keep `AGENTS.md` focused on repository workflow and constraints.

- Put end-user API explanations in `README.md`.
- Put package reference material in DocC.
- Put only the minimum necessary API reminders here when they affect safe code changes or test behavior.
