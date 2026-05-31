# MainActor Observation — Implementation Plan

> Tracking document for landing `@PersistentModel(observation: .mainActor)` in CoreDataEvolution.
>
> - **Implementation tracking issue:** [#12](https://github.com/fatbobman/CoreDataEvolution/issues/12)
>   (this document is its guide).
> - **Research / validation source:** [#11](https://github.com/fatbobman/CoreDataEvolution/issues/11)
>   and [`MainActorObservationMechanism.md`](MainActorObservationMechanism.md).
>   The runtime mechanism is validated by the `ObservationSpike` suite
>   ([`Tests/CoreDataEvolutionTests/Observation/ObservationSpikeTests.swift`](../../Tests/CoreDataEvolutionTests/Observation/ObservationSpikeTests.swift),
>   46 tests, all passing under `com.apple.CoreData.ConcurrencyDebug=1`).
> - **This document** is the ordered, testable build plan. It is written so that several independent
>   dev contexts can pick it up cold and execute steps **in order**, each acting as the implementing
>   "dev".
>
> Conventions for every step below:
> - **Touch points** name real files. Paths are relative to the repo root.
> - **Validated reference** points to the spike prototype to lift from. The spike types are
>   `private` test helpers; treat them as *reference implementations*, not copy-paste runtime code.
> - **Recommended direction** records what has already been tried and what looks better. The final
>   shape is the implementing dev's call — deviate if you find something cleaner, but record why.
> - **Tests & acceptance** must be runnable. Use `bash Scripts/run-tests.sh --filter <name>`
>   (it injects `com.apple.CoreData.ConcurrencyDebug=1`; bare `swift test` does not — see
>   [`AGENTS.md`](../../AGENTS.md) "Build And Test Commands").
> - **Done when** is the exit gate. Do not start the next step until the previous one's gate is green.

---

## Contribution Workflow (direct commit, no PR)

This feature is built by sequential dev sessions on **one integration branch** —
`feature/issue-12-mainactor-observation`. **Do not open pull requests.** Commit directly to the
integration branch. This is a deliberate choice by the maintainer; follow it exactly.

Each dev session:

1. `git checkout feature/issue-12-mainactor-observation && git pull` — start from the latest branch
   state (the previous step's commits).
2. Do exactly **one step** (the lowest unchecked step in issue
   [#12](https://github.com/fatbobman/CoreDataEvolution/issues/12)). Stay sequential — one session, one
   step, in order. Do **not** fan out parallel work, even where the plan notes a step *could*
   parallelize; the single-branch direct-commit model assumes one writer at a time.
3. Reach the step's **Done when** gate: `bash Scripts/run-tests.sh` (and the step's
   `--filter <name>`) green under `com.apple.CoreData.ConcurrencyDebug=1`, with **no** Core Data
   threading violation. The green gate is the safety mechanism here — there is no PR review to catch a
   red step.
4. Commit on the branch, one (or a few coherent) commit(s) per step. Message format:
   `Step N: <short description> (#12)`, ending with the repo's
   `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>` trailer.
5. `git push`. Then tick the step's `- [ ]` box in issue #12. That checklist is the project board;
   `git log --oneline` shows where the work stands.

Review and naming:

- **Review is local, not a PR.** The maintainer reads `git diff` / the session's own summary / `git
  show <commit>`. Per-step commits keep each step independently reviewable (`git show`).
- **Public API names are the maintainer's call.** At the steps that land public symbols
  (`PersistentModelObservationMode` in Step 1; `CDEObservationDomain`, `saveObservedChanges`,
  `registerChangeProducer` in Steps 4/6/7), surface the proposed names in the session summary so the
  maintainer can confirm or rename **before** the commit.
- **If a step's "Done when" is not green, do not hand off.** Fix it, or stop and report — never commit
  a red step onto the integration branch.
- Periodically `git merge origin/main` (or rebase) into the integration branch to avoid drift; the
  whole branch merges to `main` once the MVP gate is met.

---

## 0. Read Before You Touch Anything

Required reading, in this order:

1. [`MainActorObservationMechanism.md`](MainActorObservationMechanism.md) — the mechanism, all four
   change sources, the degradation rules, and the spike conclusions (T01–T22).
2. The spike file itself. The reusable prototypes live above the `@Suite("Observation Spike")`
   line and include: `CDEObservationDomainSkeleton`, `CDEObservationDomainRegistry`,
   `CDEObservationGetterRuntime`, `ObservationObjectIDTable`, `ObservationChangeBuffer`,
   `ObservationFieldMap` / `ObservationFieldSet` / `ObservationFieldID`,
   `ObservationHubSelector`, `ObservationLifecycleHub`, `ObservationInvalidationPlanner`,
   `ObservationRegisteredContextDomain`, `ObservationRegisteredContextProducer`,
   `ObservationSaveToken`, `ObservationPendingChange`.
3. The macro pipeline you will extend: [`PersistentModelMacro.swift`](../../Sources/CoreDataEvolutionMacros/PersistentModel/PersistentModelMacro.swift),
   [`PersistentModelModelParsing.swift`](../../Sources/CoreDataEvolutionMacros/PersistentModel/PersistentModelModelParsing.swift)
   (`autoAttachedAttribute`), [`AttributeMacro.swift`](../../Sources/CoreDataEvolutionMacros/AttributeMacro.swift),
   [`AttributeAccessorBuilders.swift`](../../Sources/CoreDataEvolutionMacros/Attribute/AttributeAccessorBuilders.swift),
   [`RelationshipMacro.swift`](../../Sources/CoreDataEvolutionMacros/RelationshipMacro.swift),
   and the public surface in [`Macros.swift`](../../Sources/CoreDataEvolution/Macros.swift).

### Three load-bearing facts the mechanism doc under-states

These are not blockers — the plan is sound — but you must internalize them, because they reorder the
work relative to the "Implementation Phases" list in the mechanism doc.

1. **`@PersistentModel` does not generate accessors itself.** Getters/setters come from the
   auto-attached peer macros `@Attribute` (`AccessorMacro`) and `@_CDRelationship`. The
   `observation` mode is declared on `@PersistentModel`, so it has to be *propagated* to those
   accessor macros before a getter can emit an `access(...)` call. The propagation channel that
   already exists is the hidden argument on the auto-attached attribute (see `_CDRelationship`'s
   `_fromPersistentModel: Bool` in [`Macros.swift`](../../Sources/CoreDataEvolution/Macros.swift)
   and [`PersistentModelModelParsing.swift`](../../Sources/CoreDataEvolutionMacros/PersistentModel/PersistentModelModelParsing.swift)).

2. **Manually-annotated properties are the hard case.** When the user writes `@Attribute(.unique)`,
   `@Attribute(storageMethod: .codable)`, or `@Relationship(...)` by hand, `@PersistentModel`'s
   `MemberAttributeMacro` attaches *nothing* (it returns `nil` if a marker is already present) and it
   cannot edit the user's attribute. So the auto-attach propagation channel does **not** reach
   manually-annotated properties. If unsolved, those properties silently never call `access(...)` and
   become invisible to Observation — a correctness hole, not an ergonomics nit. Step 2 exists to close
   this before anything else is built.

3. **No spike covers real macro codegen.** All 46 spike tests use *hand-written* `Observable`
   conformances (e.g. `ObservationSpikeItem: NSManagedObject, Observable`). The runtime half is at
   high confidence; the **macro-generation half is unproven**. `ObservationIsolationTests` only
   asserts the *negative* (non-opt-in output stays Observation-free). Treat Steps 1–3 as the real
   risk and de-risk them first.

### Positioning: the win is unconditional; precision is a bonus

The cognitive win — deleting `@Observable` wrapper layers and reading the object graph directly — comes
from per-instance subscription and is **independent of precision**. It holds even when a change uses
objectID-only all-key fallback; precision only controls whether a *sibling* property's change also
wakes a reader. The all-key fallback floor equals the existing `objectWillChange` (Combine) granularity
— worst case is parity with today, precise paths are strictly better, no path is worse. Build and test
with this ordering: **the structural win is the guaranteed deliverable; precision is a layered,
degradable optimization.** Full statement: mechanism doc → "Design Intent: Cognitive Liberation Is
Unconditional".

### Known limitations to carry into docs and the tracking issue (not bugs — scope)

The whole reactivity contract reduces to one precondition: **CDE generated the accessor.** That yields
two independent boundaries — what can *subscribe* (getter side) and what can be *detected* as changed
(producer side):

- **Subscription side — only CDE-generated accessors are observable.** Observation subscribes by
  calling `access(...)` inside a generated getter. A property whose accessor CDE does **not** generate
  has no injection point and never subscribes — it is not observable *at all*, not even
  objectID-fallback. This covers:
  - **`@NSManaged` (raw) properties:** the accessor is synthesized dynamically by Core Data at runtime;
    there is no Swift getter body to instrument. Out of scope by construction (Step 1 handles the
    skip + warning).
  - **User-written custom getters** over raw storage: same — no CDE getter, no `access(...)`.
  - Note: a **computed property built on observable stored properties** *stays* reactive, because it
    reads those instrumented getters; it needs no special handling.
- **Detection side, timing — save-gated.** Generated setters are Core Data write funnels only; they do
  **not** call `withMutation`. A view reading `model.name` refreshes after a save / merge, **not** on
  an unsaved in-memory edit. Plain `viewContext.save()` *is* precise out of the box (Step 4, "producer
  by construction"). The "immediate unsaved layer" is explicit future work and is **not** required for
  the issue #11 workflow, which drives refresh from explicit saves and background/sync merges.
- **Detection side, precision.** Manually-unregistered background contexts, raw KVC across unmanaged
  contexts, batch ops, and external/CloudKit imports are objectID-or-nothing, never property-precise,
  in MVP.
- **CloudKit property-precision is a spike, not a promise** (Step 10). Keep it out of the MVP gate.

---

## 1. Macro Opt-In Parsing and Isolation Diagnostics

**Objective.** Add `observation:` to the `@PersistentModel` surface and parse it, with zero change to
existing call sites and zero Observation tokens on the non-opt-in path.

**Touch points.**
- Public API: [`Macros.swift`](../../Sources/CoreDataEvolution/Macros.swift) — add the mode enum and
  the defaulted macro argument.
- Parsing: [`PersistentModelArgumentParsing.swift`](../../Sources/CoreDataEvolutionMacros/PersistentModel/PersistentModelArgumentParsing.swift)
  and the `PersistentModelArguments` struct in
  [`PersistentModelTypes.swift`](../../Sources/CoreDataEvolutionMacros/PersistentModel/PersistentModelTypes.swift).
- Diagnostics path already exists via `MacroDiagnosticReporter` (used throughout
  `PersistentModelMacro`).

**Recommended direction (dev decides).**
- Public enum on the library surface, *without* importing `Observation` in the declaration API:
  ```swift
  public enum PersistentModelObservationMode: Sendable {
    case none      // default; byte-for-byte today's output
    case mainActor // opt-in
  }
  ```
  (The mechanism doc proposes `.none`/`.mainActor`. Consider `.disabled` to avoid reader confusion
  with `Optional.none`; cosmetic, your call.)
- Macro signature gains a defaulted argument so every existing site keeps compiling:
  ```swift
  @PersistentModel(generateInit: false, generateToManyCount: true, observation: .none)
  ```
- In `parsePersistentModelArguments`, parse **only** literal `.none` / `.mainActor` member-access
  expressions at first; diagnose any non-literal with the existing error style.
- Diagnostics to add (literal-level only in this step; deeper checks come with codegen):
  - attached type is not an `NSManagedObject` subclass (already diagnosed — confirm it fires before
    observation work).
  - missing explicit `@objc(EntityName)` (already diagnosed — confirm).
  - `observation: .mainActor` used but the value is not a recognized literal.
  - **`@NSManaged` properties on an observed model** — they cannot subscribe (no getter to inject
    `access(...)` into; see Known Limitations / subscription side). Two things here:
    1. Make `autoAttachedAttribute`
       ([`PersistentModelModelParsing.swift`](../../Sources/CoreDataEvolutionMacros/PersistentModel/PersistentModelModelParsing.swift))
       **skip** `@NSManaged` properties so it does not auto-attach `@Attribute`. *Latent bug, verify
       it:* today `autoAttachedAttribute` does not recognize `@NSManaged` (the macro target has zero
       `@NSManaged` handling), so a `@NSManaged var name: String` falls through to `return "@Attribute"`
       and the generated `value(forKey:)` body conflicts with `@NSManaged`. Skipping it both fixes that
       conflict and lets raw `@NSManaged` coexist *inside* a `@PersistentModel` class, not only in
       non-macro subclasses.
    2. Under `observation: .mainActor`, emit a **warning** (never an error — raw `@NSManaged` must keep
       compiling) telling the user the property will not participate in observation.

**Tests & acceptance.**
- Extend [`ObservationIsolationTests.swift`](../../Tests/CoreDataEvolutionMacroTests/ObservationIsolationTests.swift):
  - existing test (non-opt-in stays Observation-free) must still pass unchanged.
  - new: `@PersistentModel(observation: .none)` expansion is byte-for-byte identical to no-argument
    expansion (assert via `MacroTestSupport.expand` that both `expandedSource` strings match, and
    that neither contains `Observation`/`ObservationRegistrar`/`@Observable`).
  - new: `@PersistentModel(observation: .mainActor)` parses without diagnostics (output can still be
    unchanged at this step — wiring comes later).
  - new: a bogus `observation: 123` literal produces exactly one diagnostic.
- Snapshot guard: confirm the existing `__Snapshots__/PersistentModelBasic.*` snapshots are unchanged
  (run `bash Scripts/run-tests.sh --filter MacroExpansionSnapshot`).

**Done when.** `bash Scripts/run-tests.sh --filter "Observation Isolation"` and
`--filter MacroExpansionSnapshot` are green, and `swift build` is clean. No runtime types exist yet.

---

## 2. Macro Codegen De-Risking Spike (the critical step)

**Objective.** Prove, in real macro expansion, that the opt-in path can (a) make a generated **getter**
call `access(...)`, (b) emit `Observable` conformance + a stored `ObservationRegistrar`, and (c) do
both for **auto-attached and manually-annotated** `@Attribute` / `@Relationship` properties — while
the non-opt-in path stays exactly as today. **Resolve the propagation problem before building runtime.**

This is a spike: it may land disposable scaffolding and a throwaway expansion test. Its output is a
**decision**, recorded in this doc, plus the minimal generation hooks the later steps depend on.

**The propagation problem, concretely.** The accessor macros (`@Attribute`, `@_CDRelationship`) only
see their own node + the property declaration. They do not see `@PersistentModel(observation:)`.
Channels to evaluate:

1. **Hidden argument on the auto-attached attribute** (mirrors `_fromPersistentModel: true`). In
   `autoAttachedAttribute`, when observation is on, emit `@Attribute(_observation: .mainActor)` /
   `@_CDRelationship(..., _observation: .mainActor)`. Accessor builders read it from their own node.
   - ✅ Works for auto-attached properties.
   - ❌ Does **not** reach manually-written `@Attribute(...)` / `@Relationship(...)`.
2. **Sibling marker visible to the accessor macro.** Have `@PersistentModel`'s `MemberAttributeMacro`
   attach a separate hidden marker (e.g. `@_CDObserved(.mainActor)`) to *every* stored property,
   including ones that already carry a user `@Attribute`. The `@Attribute` accessor macro then
   inspects `declaration.attributes` for `@_CDObserved` and conditionally emits `access(...)`.
   - ⚠️ Depends on Swift expanding the member-attribute macro *before* the accessor macro **and** the
     injected attribute being visible in the accessor macro's `declaration`. This ordering/visibility
     has been historically fragile. **Verify it empirically in this step.** If it holds, it is the
     cleanest answer because it covers manual annotations uniformly.
3. **Fold accessor generation into a dedicated observed path.** If neither channel is reliable for
   manual annotations, require that observation models route accessor generation through the macro's
   own member generation (e.g. `@PersistentModel` diagnoses a manual `@Attribute` on an observed
   model and instructs the user to drop it, or the macro re-derives storage info and the accessor
   macro becomes a thin shim). Least desirable; record exactly why if you land here.

**Validated reference.** The *runtime* shape of the getter wrapper is the spike's
`CDEObservationGetterRuntime.registerObservedObjectIfNeeded(_:)` plus
`CDEObservationDomainRegistry.domain(for:)`. The stored-registrar-on-`NSManagedObject` pattern is
proven by `ObservationSpikeItem`/`ObservationDomainItem` and tests **T01, T04, T05** (registrar
survives faulting, rekey, release). Lift the *contract*, not the test helper.

**Recommended direction (dev decides).**
- Generated getter for an observed scalar should expand to roughly:
  ```swift
  get {
    CoreDataEvolution._cdeObservationAccess(self, \.<prop>)   // registrar.access + domain register
    // …existing value(forKey:) body…
  }
  ```
  where `_cdeObservationAccess` is an `@available(iOS 17, macOS 14, …, *)` runtime shim (defined in
  Step 4's module) so the user model file never imports `Observation` directly.
- Emit `Observable` conformance + `let _$observationRegistrar` storage **only** on the opt-in path,
  all behind the availability gate.
- Naming must dodge the isolation test: the non-opt-in expansion must contain **no** substring
  `Observation`, `ObservationRegistrar`, or `@Observable`.

**Tests & acceptance.**
- New expansion tests (macro test target) proving, for an `observation: .mainActor` model with **both**
  an auto-attached `var name: String` **and** a manual `@Attribute(.unique) var code: String`:
  - both getters contain the `access`/shim call,
  - the type gains `Observable` + registrar storage,
  - all observation members are availability-gated.
- The non-opt-in isolation tests from Step 1 still pass (the negative guard is now load-bearing).
- A short written decision appended to **this section** naming the chosen propagation channel and the
  empirical ordering/visibility result for channel (2).

**Step 2 decision (2026-05-31).** Chosen propagation channel: sibling marker
`@_CDObserved(.mainActor)` attached by `@PersistentModel`'s `MemberAttributeMacro` to each eligible
stored property. Empirical result: in real `SwiftSyntaxMacroExpansion` output, the marker is visible
to both manually-written `@Attribute(...)` accessor macros and the auto-attached `_CDRelationship`
accessor macro generated for public `@Relationship(...)` declarations. The opt-in model therefore
gets registrar storage, `CDEObservable` conformance, and getter access injection for both auto
attributes and manually annotated attributes/relationships; non-opt-in expansion remains unchanged
by the isolation and snapshot gates.

**Done when.** Real macro expansion produces an `access`-instrumented, `Observable`-conforming model
for both annotation styles; the non-opt-in path is provably unchanged; the propagation decision is
recorded here. **Do not proceed to runtime build until this gate is green** — every later step assumes
generated getters can subscribe and the model can be invalidated.

---

## 3. Generated Field Identity Table and Core Data Key Fan-Out

**Objective.** Generate, for opt-in models only, a compact observable field-identity table and a
**one-to-many** `Core Data key → observable field` fan-out, so the hub can turn `changedValues()`
string keys into precise invalidations — including derived to-many counts and composition top-level.

**Touch points.**
- Generation: [`PersistentModelMemberGeneration.swift`](../../Sources/CoreDataEvolutionMacros/PersistentModel/PersistentModelMemberGeneration.swift)
  (sits beside the existing `__cdFieldTable` / `__cdRelationshipProjectionTable` and
  `makeToManyCountDecls`). The persistent-name → swift-name inversion can be derived from the data
  already in `__cdFieldTable` (`CDFieldMeta.persistentPath`), see
  [`PathProtocols.swift`](../../Sources/CoreDataEvolution/TypedPath/PathProtocols.swift).
- Assembly: add the new decls to the opt-in branch of
  [`PersistentModelMacro.swift`](../../Sources/CoreDataEvolutionMacros/PersistentModel/PersistentModelMacro.swift)'s
  `MemberMacro` expansion (guarded by `arguments.observation == .mainActor`).

**Validated reference.** Spike **T07, T08, T15, T16** and the helpers `ObservationFieldID`,
`ObservationFieldSet`, `ObservationFieldMap`, `ObservationSaveHookKeyMap`. The fan-out rules they
encode and that you must reproduce:
- `name → {name}`
- `children → {children, childrenCount}` and `orderedChildren → {orderedChildren, orderedChildrenCount}`
  (relationship key fans out to the generated count from `makeToManyCountDecls`).
- composition backing key → top-level composition property only (leaf precision is future work, T16).

**Recommended direction (dev decides).**
- Generate a compact `FieldID` (a `UInt8`/`OptionSet`-style set is what T08 modeled) so the buffer and
  hub can store small field sets, not string arrays. String keys remain fine for diagnostics.
- Keep the map keyed by the **persistent** Core Data key (that is what `changedValues()` returns) and
  valued by the set of observable field IDs / generated key paths.
- Transient and `@Ignore` fields produce **no** Core Data key entry (T07/T16) — do not invent one.

**Tests & acceptance.**
- Macro expansion test: an opt-in model with a to-one, an unordered to-many, an ordered to-many, an
  attribute, and a `@Composition` field generates a fan-out where each to-many key maps to both the
  relationship field and its count field, and the composition backing key maps to the top-level
  property.
- A focused unit test that drives the generated table with sample `changedValues()` keys and asserts
  the produced field set matches the T08 matrix.
- Non-opt-in model generates **no** fan-out table (isolation guard).

**Done when.** `--filter` over the new field-table tests is green; the fan-out reproduces the T07/T08
matrix; non-opt-in output is unchanged.

---

## 4. Runtime Core — `CDEObservationDomain`, Hub, Weak Table, Pending Buffer

**Objective.** Land the container-bound runtime owner and its MainActor hub + observed-object weak
table + pending metadata buffer as real (non-test) code, with the MainActor/producer split intact.

**Touch points.** New runtime source under `Sources/CoreDataEvolution/` (suggested directory
`Sources/CoreDataEvolution/Observation/`). Availability-gate everything. This is where the
`_cdeObservationAccess` shim from Step 2 is defined.

**Validated reference.** Promote, do not invent:
- `CDEObservationDomainSkeleton` + `CDEObservationDomainRegistry` + `CDEObservationGetterRuntime`
  (T22): retained domain ↔ `viewContext` association; getter-driven, registration-free observed-object
  capture; `invalidate()` / deinit cleanup; multi-container isolation.
- `ObservationObjectIDTable` (T04, T09): `observed objectID → weak object`, prune released, rekey
  temp→permanent, drop on delete/reset.
- `ObservationChangeBuffer` + `ObservationSaveToken` + `ObservationPendingChange` (T12): per-token
  contributions, merge of key sets, consume-by-objectID, rollback-by-token, compress-to-all-keys
  while keeping identity. **Domain-scoped, with a synchronous thread-safe staging path** (it already
  uses an `NSLock`) so background/notification callbacks can write before the merge.
- `ObservationHubSelector` (T09, T20): merge routing **bounded by incoming object IDs**; consume
  pending even when no live observed object remains; notify only live observed instances.

**Recommended direction (dev decides).**
- Public init `CDEObservationDomain(container:)` on `@MainActor`; the registry association keys on the
  container's `viewContext` exactly as T22.
- Keep Observation publication + weak table **MainActor-only**; keep buffer staging synchronous and
  lock-guarded. Do **not** route producer staging through an async MainActor hop (T12 invariant — it
  would break pre-merge ordering).
- Wire `viewContext` merge/lifecycle notification observation here, but keep the *decision* logic in
  the lifted `ObservationHubSelector` / `ObservationLifecycleHub` shapes.
- **viewContext is a producer by construction.** At `init`, the domain installs `willSave` /
  `objectsDidChange` / merge observers on its *own* `viewContext`, so a plain `viewContext.save()` is
  property-precise with **no** special API. Local saves (own `willSave`; snapshot `changedValues()` in
  the will-save window per T06) and background merges (merge notification) are **disjoint** paths →
  no double-fire. This is load-bearing for the issue #11 workflow (explicit saves, no autosave): "read
  the graph, save, it refreshes" must hold without the user calling a special save method. Background
  contexts, by contrast, are producers only when explicitly registered (Step 7).

**Tests & acceptance.** Port the relevant spike assertions to runtime-level tests (they currently test
private helpers; now they test the public/internal runtime types):
- domain activation + getter registration without per-object registration (T22),
- **plain `viewContext.save()` (no special API)** → observed object invalidates the exact changed
  field (the producer-by-construction guarantee),
- merge routing cost is O(incoming IDs), no scan over registered/observed/pending history (T20),
- buffer merge/consume/rollback/compress/scope (T12),
- weak table prune/rekey/delete/reset (T04, T09).
- All under `com.apple.CoreData.ConcurrencyDebug=1` with **no** threading violations.

**Done when.** A retained `CDEObservationDomain` over a real `makeTest` container associates with the
`viewContext`, a generated getter (from Step 2) registers the object, and a manually-staged pending
change consumed at merge invalidates exactly the right field — proven by a runtime test, not a spike
helper.

---

## 5. Generated Registrar Dispatch Wired to the Hub

**Objective.** Connect the macro-generated invalidation dispatcher to the hub so that, given a field
set for an object, the hub calls `registrar.withMutation`/`willSet`-style invalidation for exactly the
derived key paths (relationship **and** its count).

**Touch points.** Macro generation in
[`PersistentModelMemberGeneration.swift`](../../Sources/CoreDataEvolutionMacros/PersistentModel/PersistentModelMemberGeneration.swift)
(emit a per-model dispatcher that maps `FieldID`/key → registrar invalidation), plus the hub call site
from Step 4.

**Validated reference.** T08 (field set → dispatch), T15 (relationship + count fan-out must both
fire), T01 (external registrar invalidation is property-scoped and actually reaches a SwiftUI-tracked
read).

**Recommended direction (dev decides).**
- The dispatcher is the single place the hub calls after save/merge. It must honor the Step 3 fan-out:
  invalidating `children` fires both `\.children` and `\.childrenCount`.
- `.allObservableKeyPaths` degradation iterates the model's full observable key-path set for that one
  object — **per-object, never across the relationship graph** (T15, T20).

**Tests & acceptance.**
- Runtime test: stage a precise `children` change → assert both `children` and `childrenCount`
  invalidations dispatch.
- Runtime test: stage `.allObservableKeyPaths` → assert every observable key path for that object
  fires and **no** traversal into related objects happens.

**Done when.** The hub can drive generated dispatch end-to-end for one object from a staged field set,
with correct count fan-out and bounded all-key degradation.

---

## 6. CDE-Managed Save Producers (`NSModelActor` / `NSMainModelActor`)

**Objective.** Make CDE-owned saves precise: snapshot `objectID + changedValues()` keys before
`save()` returns, register a token in the target domain before the merge reaches `viewContext`, and
roll back on failure.

**Touch points.** [`NSModelActor.swift`](../../Sources/CoreDataEvolution/NSModelActor.swift),
[`NSMainModelActor.swift`](../../Sources/CoreDataEvolution/NSMainModelActor.swift),
[`ModelActorSupport.swift`](../../Sources/CoreDataEvolution/ModelActorSupport.swift). Add the
domain-aware save entry points.

**Validated reference.** **T10** (NSModelActor save wrapper produces metadata, defines bypass
fallback), **T06** (`changedValues()` is empty after `save()` returns — snapshot in the will-save
window), **T13** (merge alignment via `didMergeChangesObjectIDsNotification`), **T17** (inserts: full
new object, but existing relationship owners stay precise; temp-ID rekey point).

**Recommended direction (dev decides).**
- API receives the domain explicitly (no hidden global registry):
  ```swift
  extension NSModelActor {
    public func saveObservedChanges(in observation: CDEObservationDomain) async throws
  }
  @MainActor extension NSMainModelActor {
    public func saveObservedChanges(in observation: CDEObservationDomain) throws
  }
  ```
  `NSModelActor` variant is `async` because metadata must become visible before the background save
  merges into `viewContext`; the main variant is synchronous (already on `viewContext`).
- Snapshot **non-temporary** `updatedObjects` + their `changedValues()` keys; ignore inserts for
  property-level metadata; register the token **before** `save()`; roll back the token if `save()`
  throws.
- Document direct `modelContext.save()` (bypassing the wrapper) as objectID-only fallback.
- **`NSMainModelActor.saveObservedChanges(in:)` is ergonomic sugar, not a correctness requirement.**
  A plain `viewContext.save()` is already property-precise via the domain's viewContext instrumentation
  (Step 4, producer by construction). Keep the wrapper for symmetry with the background path, but local
  precision must **not** depend on it.

**Tests & acceptance.** Runtime tests over a `makeTest` container with a real `@NSModelActor` handler
(follow [`AGENTS.md`](../../AGENTS.md) "Test Requirements": prefer actor handlers, `automatically­MergesChangesFromParent = true`):
- background `saveObservedChanges` → observed `viewContext` object invalidates the exact changed field
  after merge.
- background save **failure** → no token promotion, buffer clean.
- insert a child + attach to an existing observed parent → parent's `children`/`childrenCount`
  invalidate; child needs temp→permanent rekey before it can be observed (assert the rekey hook).
- direct `modelContext.save()` → objectID-only all-key fallback.

**Done when.** A real background actor save drives a precise MainActor invalidation through the domain,
with failure rollback proven, under the concurrency-debug flag.

> **Ordering note for reviewers.** T10/T13 proved this with *synchronous* spike doubles. The genuine
> async-actor ordering ("token staged before the main-queue merge notification is consumed") must be
> re-proven here against the real executor, not assumed from the spike. Keep "register token before
> `save()`" as a hard invariant and add a test that would fail if staging raced the merge.

---

## 7. Registered Ordinary Background Context Producer + Cleanup Contract

**Objective.** Let an app-owned ordinary background context keep plain `context.save()` precise by
registering it with the domain — without swizzling and without a default `NSManagedObjectContext`
extension.

**Touch points.** Runtime under `Sources/CoreDataEvolution/Observation/`. Public surface on
`CDEObservationDomain`:
```swift
@MainActor func registerChangeProducer(context:) -> CDEObservationProducerRegistration
@MainActor func newObservedBackgroundContext() -> NSManagedObjectContext   // convenience
func saveObservedChanges(in context:) async throws                          // stricter-failure wrapper
```

**Validated reference.** **T21** (registered ordinary context direct save stays precise before
automatic *and* manual merge; unregistered falls back; producer/container scope isolation; failure /
reset / invalidation cleanup) and `ObservationRegisteredContextProducer` /
`ObservationRegisteredContextDomain`.

**Recommended direction (dev decides).**
- Registration installs context-scoped observers for `willSave` (stage `objectID + changedValues()`),
  `didSave` (promote), plus rollback/reset/dealloc cleanup.
- **The open contract you must close:** a pure notification observer cannot learn about a *thrown*
  `save()` (no `didSave` fires). Pick and document one:
  1. registered direct-save is "best effort precise; on throw you must `rollback()`/reset" (caller
     contract), **or**
  2. steer failure-sensitive callers to `saveObservedChanges(in:)`, which catches the throw and rolls
     back its own token.
  T21 passed rollback-after-failure at the spike-helper level; the runtime must make the choice explicit.
- **Chosen Step 7 contract.** Registered direct `context.save()` stages metadata locally at `willSave`
  and publishes it only at `didSave`; after a thrown direct save, callers must `rollback()`, `reset()`,
  or invalidate the registration to clear staged notification state. Failure-sensitive callers should
  use `CDEObservationDomain.saveObservedChanges(in:)`, which rolls back its own staged token and the
  context on throw.

**Tests & acceptance.** Port the five T21 tests to runtime:
- registered direct save precise before automatic merge,
- unregistered direct save → all-key fallback,
- manual-merge consumption point,
- multi-producer / multi-container scope isolation,
- failure + reset + invalidation cleanup leaves no stale precise metadata.

**Done when.** A registered ordinary `newBackgroundContext()` makes plain `context.save()` precise in a
runtime test, the chosen thrown-save contract is implemented and tested, and unregistered contexts
degrade correctly.

---

## 8. Batch and Lifecycle Fallback

**Objective.** Implement the conservative, object-scoped fallbacks so the hub never over-promises or
touches invalid instances.

**Touch points.** Hub + buffer in `Sources/CoreDataEvolution/Observation/`.

**Validated reference.** **T14** (batch update/delete: object IDs → all-key; status-only → no
guarantee), **T18** (fault / refresh / invalidation / rollback / delete / reset table), **T04/T17**
(temp→permanent rekey).

**Recommended direction (dev decides).** Reproduce the T18 event table exactly:

| Event | Hub | Buffer | Weak table |
|---|---|---|---|
| fault | none | keep | keep |
| refresh / invalidation | all-key for object | clear that ID | keep while live |
| rollback | all-key for affected | rollback tokens + clear | keep |
| delete | do **not** invalidate the deleted instance | clear that ID | unregister |
| reset | none after clear | clear all | clear all |

- Batch: merge the result object IDs and route to all-key; never enter property-precision.
- Faulted observed object re-registers on next getter read (T18) — do not break that.
- Runtime refinement (added during implementation): the `refresh → all-key` row holds for a *new*
  refresh, but the same-cycle echo of a precise merge for the same object is suppressed instead of
  widened, so a precise save is not re-broadened by a duplicate merge / refresh in its own cycle. See
  [`MainActorObservationMechanism.md` → Same-Cycle Precise-Merge Suppression](MainActorObservationMechanism.md#same-cycle-precise-merge-suppression).

**Tests & acceptance.** Runtime versions of T14 + T18 (refresh/rollback/delete/reset/fault) +
temp-ID rekey on save-driven insert. All under the concurrency-debug flag.

**Done when.** Every lifecycle event in the T18 table behaves as specified in a runtime test, batch ops
are all-key-only, and no test trips a Core Data threading violation.

---

## 9. End-to-End SwiftUI / Observation Integration Proof

**Objective.** The actual product claim: an external (background/merge) change to a property drives a
**property-level** Observation invalidation that a real `withObservationTracking` consumer sees, and an
*unrelated* property change does **not** wake it. Plus the multi-layer relationship win from issue #11.

**Touch points.** New test suite, e.g.
`Tests/CoreDataEvolutionTests/Observation/ObservationIntegrationTests.swift`, using a real opt-in
model compiled through the macro (not a hand-written `Observable`). Reuse `TestStack` / `makeTest`
and `@NSModelActor` handlers per [`AGENTS.md`](../../AGENTS.md).

**Validated reference.** **T01** is the in-spike analog (external registrar invalidation reaches a
tracked read). This step elevates it to a real generated model end-to-end.

**Recommended direction (dev decides).**
- Drive with `withObservationTracking { _ = model.name } onChange: { … }` on MainActor; assert the
  `onChange` fires for a precise background edit to `name` and does **not** fire for an edit to a
  sibling property the closure never read.
- A deep-read test (`root.child.leaf.name`) proving per-instance subscription: changing only `leaf.name`
  wakes a closure that read it, without the mechanism walking the graph (issue #11's motivating case).
- A "read only `ordersCount`" test proving the count fan-out (Step 3) actually refreshes a count-only
  reader.
- **Win-holds-under-fallback test** (operationalizes the "Positioning" thesis): run the same deep-read
  scenario but drive the change through an objectID-only path (unregistered context or batch) and
  assert the reader still refreshes — the wrapper-deletion / penetration win is precision-independent;
  fallback only widens *which* sibling reads also wake, it never loses the structural win.

**Tests & acceptance.**
- `bash Scripts/run-tests.sh --filter ObservationIntegration` green.
- Explicit negative assertions (unrelated property does not invalidate) — these are the proof the
  feature is *property-level*, not object-level.

**Done when.** A generated opt-in model, changed from a CDE-managed background save, produces a
precise MainActor Observation refresh end-to-end, with the negative (no over-invalidation) proven.

---

## 10. Selective Context Save Hook Spike (optional, opt-in) — CloudKit / framework-owned contexts

**Objective.** Explore property-precision for contexts CDE does **not** own (CloudKit import,
framework-owned sync) via an explicitly installed, removable notification hook. **This stays a spike
and out of the MVP gate.** Persistent History Tracking is explicitly **not** the route.

**Touch points.** Optional hook surface on `CDEObservationDomain`
(`installContextNotificationHook(scope:)`), kept out of the default module unless enabled (package
trait or separate product — see the mechanism doc's "`NSManagedObjectContext` Extension Strategy").

**Validated reference.** The mechanism doc's "Selective Context Save Hook Exploration": one real
device→device probe saw a framework-owned import context post
`NSObjectsChangedInManagingContextNotification` + `NSManagingContextWillSaveChangesNotification` with
the business entity (`Note.descriptionContent`) **before** the main `viewContext`
`didMergeChangesObjectIDsNotification`. That is *one* path, not a guarantee.

**Recommended direction (dev decides).**
- Candidate 1 (preferred): opt-in global notification observer with `object: nil`, filtered by
  persistent store coordinator / store identity / affected object IDs before staging. No swizzling.
- Candidate 2 (fallback only): save interception — higher risk, no default install, no silent
  swizzle in the base library.
- Candidate 3 (always available): the Step 7 registered-context route stays the stable path for
  app-owned contexts.
- Must ignore CloudKit metadata entities (`NSCKRecordMetadata`, `NSCKEvent`, `NSCKRecordZoneMetadata`)
  and must never publish Observation from the import notification thread (the probe surfaced
  background-publish warnings).

**Tests & acceptance (automatable portion).**
- Hook is **absent** from the default build unless enabled (compile-condition / product test).
- With the hook installed against a *simulated* framework-owned context (a second context the test
  owns but does not register), staging happens before the `viewContext` merge consumes object IDs.
- Filtering rejects unrelated containers/stores; uninstall/reset/dealloc leave no stale metadata.

**Done when.** The hook installs/uninstalls cleanly, is opt-in and scoped, stages before merge in a
simulated case, and degrades to objectID-only when it cannot. The *real* CloudKit matrix is Step 11.

---

## 11. iCloud / CloudKit Device-to-Device Validation (manual — run by maintainer)

> Automated tests cannot cover real `NSPersistentCloudKitContainer` device-to-device sync. This step
> is **manual**; the implementing dev only needs to deliver a host app + a written checklist. The
> maintainer (Fatbobman) runs it.

**Deliverable for the dev.** A minimal two-target (or one app, two devices) host app using
`NSPersistentCloudKitContainer` with an opt-in `@PersistentModel(observation: .mainActor)` entity, a
retained `CDEObservationDomain(container:)`, and a SwiftUI view that reads a single attribute and a
relationship chain. Wire the Step 10 hook **on** in one build variant and **off** in another.

**Acceptance criteria (what the maintainer verifies).**
1. **Hook OFF (MVP baseline):** an attribute edited on device A, after CloudKit import on device B,
   refreshes the device-B view via the **objectID all-key fallback** (the view updates; precision is
   not promised). No crash, no background-thread Observation publish warning, no Core Data threading
   violation.
2. **Hook ON (precision spike):** the same edit refreshes device B and — when the import context
   exposed changed keys — does so at **property level** (an unrelated attribute's view does not
   refresh). Capture the notification sequence (`…WillSaveChanges…` / `…ObjectsChanged…` vs the main
   `didMergeChangesObjectIDsNotification`) to confirm staging-before-merge held.
3. **Matrix to repeat before calling CloudKit precision "supported":** attribute, to-one, to-many
   membership, composition backing field, conflict / repeated import, cold-launch import, and
   multiple stores. If any case is unreliable, **CloudKit precision stays out of MVP** and that build
   ships with hook OFF.
4. **Cleanup:** toggling the hook off / tearing down the domain leaves no stale observers (verify via
   repeated foreground/background cycles without growth in observer count or memory).

**Done when.** The maintainer signs off criteria 1 (must pass for MVP) and records the criteria 2–3
results as the CloudKit-precision decision. MVP does **not** depend on 2–3.

---

## 12. Documentation and Public API Freeze

**Objective.** Document the feature once runtime names and availability gates are stable.

**Touch points.** `README.md` (public API only), a new guide under `Docs/` (e.g.
`Docs/ObservationGuide.md`), DocC notes. Keep mechanism internals in
[`MainActorObservationMechanism.md`](MainActorObservationMechanism.md); keep this build log here.
Follow [`AGENTS.md`](../../AGENTS.md) "Documentation Scope".

**Must document.**
- The opt-in spelling, the MainActor/`viewContext`-only boundary, and the iOS 17 / macOS 14 / tvOS 17
  / watchOS 10 / visionOS 1 floor.
- The **save-gated** limitation (no immediate unsaved refresh) prominently.
- The producer matrix: CDE-managed save (precise) vs registered ordinary context (precise, with the
  thrown-save contract) vs unregistered/batch/external (objectID-or-nothing).
- CloudKit precision status from Step 11.

**Done when.** README shows only stable public API; the guide states the boundaries and limitations;
the mechanism doc is cross-linked as the research record.

---

## Execution Order, Dependencies, and Parallelism

```
Step 1 ── Step 2 ──┬── Step 3 ── Step 5 ──┐
                   │                        ├── Step 9 (E2E) ── Step 11 (manual iCloud) ── Step 12 (docs)
                   └── Step 4 ──┬── Step 6 ─┤
                                ├── Step 7 ─┘
                                └── Step 8
                   Step 10 (optional hook spike) ──────────────┘ feeds Step 11
```

- **Strictly sequential gate:** Steps 1 → 2 must complete first. Step 2 is the de-risking gate; nothing
  downstream is safe until generated getters can subscribe.
- **After Step 4**, Steps 6, 7, 8 can be done by separate dev contexts in parallel (they share the hub
  but touch different producer/lifecycle surfaces) — coordinate on the buffer/hub API from Step 4.
- **Step 5** depends on Step 3 (field table) + Step 4 (hub).
- **Step 9** depends on Steps 5–8 landing.
- **Step 10** is optional and independent until it feeds Step 11.
- **Step 11** is manual (maintainer). **Step 12** is last.

## MVP Definition of Done (the gate that ships)

- `@PersistentModel(observation: .mainActor)` compiles; non-opt-in output is byte-for-byte unchanged
  (Step 1–2 isolation guards).
- Generated getters subscribe; CDE-managed background save (Step 6) and registered ordinary context
  (Step 7) drive **property-level** MainActor refresh end-to-end (Step 9), with the **negative**
  (unrelated property does not refresh) proven.
- Batch + lifecycle fallbacks behave per the T14/T18 tables (Step 8).
- iCloud criterion 1 (objectID all-key fallback, no crash/threading violation) passes manually (Step 11).
- CloudKit property-precision (Step 10 + Step 11 criteria 2–3) is **explicitly optional** and may ship
  OFF.
- All automated suites pass under `bash Scripts/run-tests.sh` (i.e. with
  `com.apple.CoreData.ConcurrencyDebug=1`).
