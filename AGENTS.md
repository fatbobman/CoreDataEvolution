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
```

Formatting, if `swift-format` is installed:

```bash
swift-format format --in-place <path-to-file.swift>
```

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

## Documentation Scope

Keep `AGENTS.md` focused on repository workflow and constraints.

- Put end-user API explanations in `README.md`.
- Put package reference material in DocC.
- Put only the minimum necessary API reminders here when they affect safe code changes or test behavior.
