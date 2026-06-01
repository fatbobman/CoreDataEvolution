# MainActor Observation Guide

`@PersistentModel(observation: .mainActor)` lets Swift Observation subscribe to
CoreDataEvolution-generated Core Data accessors.

The feature is opt-in. The default `@PersistentModel` output remains unchanged and does not generate
Observation symbols.

Use this guide when you want SwiftUI or `withObservationTracking` to read an `NSManagedObject`
directly instead of maintaining a separate `@Observable` wrapper layer.

For the internal mechanism and validation record, see
[MainActorObservationMechanism.md](./Development/MainActorObservationMechanism.md). For the staged
implementation plan, see
[MainActorObservationImplementationPlan.md](./Development/MainActorObservationImplementationPlan.md).

## Availability

MainActor Observation requires Swift Observation platform support:

- iOS 17+
- macOS 14+
- tvOS 17+
- watchOS 10+
- visionOS 1+

The package still supports lower deployment targets for its other features. Keep Observation-specific
code behind matching availability when your app targets older OS versions.

## Minimal Model

```swift
import CoreDataEvolution

@objc(Item)
@PersistentModel(observation: .mainActor)
final class Item: NSManagedObject {
  var title: String = ""
  var summary: String = ""

  @Relationship(inverse: "items", deleteRule: .nullify)
  var tag: Tag?
}
```

The opt-in model generates:

- Swift Observation conformance and registrar storage
- `access(...)` calls in CDE-generated attribute and relationship getters
- field metadata used to route saved Core Data changes back to observable key paths
- invalidation dispatch used by the observation domain

You do not normally import `Observation` in the model file. `CoreDataEvolution` owns the generated
Observation bridge.

## Activate A Domain

Model opt-in only makes the accessors observable. Runtime save and merge routing is activated by a
retained `CDEObservationDomain` for the container's `viewContext`.

```swift
@MainActor
final class Store {
  let container: NSPersistentContainer
  let observation: CDEObservationDomain

  init(container: NSPersistentContainer) {
    self.container = container
    observation = CDEObservationDomain(container: container)
  }
}
```

Keep the domain alive for as long as the UI should observe that container. Call `invalidate()` when
you intentionally tear it down early.

SwiftUI can then read the managed object directly:

```swift
struct ItemRow: View {
  let item: Item

  var body: some View {
    Text(item.title)
  }
}
```

The read of `item.title` subscribes through the generated getter. When the domain later routes a
saved change for `title`, Swift Observation invalidates that reader.

## MainActor And `viewContext` Boundary

Observation consumption is MainActor-bound and centered on `container.viewContext`.

- Read observed model objects from MainActor UI code.
- Keep `CDEObservationDomain` on MainActor.
- Treat background contexts as metadata producers only. They should not publish Observation changes
  directly.
- If an opt-in model is used without a retained domain for its `viewContext`, reads can still compile,
  but CDE does not promise save or merge invalidation routing.

## Save-Gated Refresh

The current implementation is save-gated.

Generated setters write Core Data values. They do not call `withMutation` immediately. A reader is
invalidated after a `viewContext` save, a merge from a producer context, or a lifecycle fallback.

This means unsaved in-memory edits are not promised to refresh SwiftUI immediately:

```swift
item.title = "Draft"
// No CDE Observation refresh is promised yet.

try viewContext.save()
// The retained domain routes the saved change.
```

This is deliberate. It matches the Core Data workflow used by the library and keeps background
producer ordering explicit.

## Change Producers

Use the strongest producer route that matches the context you own.

| Source | Public API | Precision | Notes |
|---|---|---|---|
| `viewContext` save | `try viewContext.save()` | property-level | A retained domain instruments its own `viewContext`; `NSMainModelActor.saveObservedChanges(in:)` is symmetry sugar. |
| `@NSModelActor` background save | `try await saveObservedChanges(in: observation)` | property-level | Stages changed keys before save without suspending between staging and commit. |
| Arbitrary context wrapper | `try await observation.saveObservedChanges(in: context)` | property-level | Preferred when thrown-save cleanup matters; the wrapper rolls back its staged token and the context on failure. |
| Registered ordinary context | `observation.registerChangeProducer(context:)`, then plain `context.save()` | property-level after successful save | If a direct save throws, call `rollback()`, `reset()`, or invalidate the registration to clear staged notification state. |
| Convenience background context | `observation.newObservedBackgroundContext()` | property-level after successful save | Equivalent to `container.newBackgroundContext()` plus producer registration. |
| Unregistered context | plain `context.save()` | objectID all-key fallback when merge provides object IDs | Sibling-property precision is not promised. |
| Batch / lifecycle operations | Core Data APIs plus normal merge notifications | objectID all-key fallback when object IDs are available | With no affected object IDs, there is no instance-level response guarantee. |
| CloudKit / external import | no stable precision API in the current release | objectID all-key fallback when merge provides object IDs | Property-level CloudKit precision remains experimental and is not a public guarantee. |

## Background Actor Save

Prefer `NSModelActor.saveObservedChanges(in:)` for actor-owned background writes:

```swift
@NSModelActor
actor ItemWriter {
  func rename(
    id: NSManagedObjectID,
    to title: String,
    observation: CDEObservationDomain
  ) async throws {
    guard let item = self[id, as: Item.self] else { return }
    item.title = title
    try await saveObservedChanges(in: observation)
  }
}
```

Calling `modelContext.save()` still saves Core Data correctly, but it bypasses CDE's precise metadata
staging. The domain can only fall back to object-level invalidation when a later merge supplies object
IDs.

## Registered Ordinary Contexts

Register app-owned background contexts when you want plain `context.save()` to remain precise:

```swift
let context = observation.newObservedBackgroundContext()

context.perform {
  do {
    // mutate observed model objects
    try context.save()
  } catch {
    context.rollback()
  }
}
```

For failure-sensitive code, prefer the wrapper:

```swift
try await observation.saveObservedChanges(in: context)
```

The wrapper can catch a thrown save and roll back its staged observation token. A registered direct
save cannot observe a thrown `save()` by notification alone; after a failure, the caller must
`rollback()`, `reset()`, or invalidate the returned registration.

## View Context Rollback

When rolling back observed `viewContext` changes, prefer:

```swift
observation.rollbackObservedChanges()
```

This snapshots updated, deleted, and inserted observed objects before calling `viewContext.rollback()`.
Updated and deleted live objects receive an object-level fallback invalidation; newly inserted
observed objects are unregistered because rollback detaches them from the persistent graph.

A direct `viewContext.rollback()` remains Core Data-correct, but it is not the documented CDE
Observation cleanup route because the domain cannot snapshot the same pre-rollback state afterward.

## What Can Be Observed

A property can be observed only when CDE generated the accessor that the view reads.

Observable paths include:

- generated `@Attribute` accessors
- generated `@Relationship` accessors
- generated to-many count accessors such as `itemsCount`
- the top-level generated accessor for `.composition` storage
- computed properties that read observable stored properties

Not observable:

- raw `@NSManaged` properties
- user-written custom getters that bypass CDE-generated accessors
- `@Ignore` properties
- properties on non-opt-in models

When `observation: .mainActor` is enabled, raw `@NSManaged` properties compile but emit a warning
because CDE cannot inject `access(...)` into Core Data's dynamic accessor.

## Precision And Fallback

Observation has two separate axes:

- subscription: did the view read a CDE-generated getter?
- detection: did the save source provide changed Core Data keys?

If both are true, the domain invalidates only the matching observable key paths. If the view read
`item.title`, a saved change to `item.summary` does not wake that reader.

If the source only provides affected object IDs, CDE uses all observable key paths for those objects.
That is the fallback used for unregistered contexts, batch operations, and external imports. It still
lets views read the object graph directly, but sibling-property precision is not promised.

If there is no affected object ID, CDE does not promise an instance-level response.

## Precision Across Store Re-merges

Some stores re-merge a just-saved change back into the `viewContext` a run-loop turn later — most
commonly `NSPersistentCloudKitContainer` (which always enables Persistent History Tracking, even
without a configured CloudKit container), but also a parent/child context chain or a manual
`mergeChanges`. That echo arrives after the precise change was already routed; left unhandled it would
widen to all observable key paths and wake readers of unchanged sibling properties.

`CDEObservationDomain` suppresses the echo so a precise save stays precise across the round trip,
controlled by `CDEPreciseRouteEchoSuppression`:

```swift
// .auto (default): on for NSPersistentCloudKitContainer, off otherwise
CDEObservationDomain(container: container)

// .on: a non-CloudKit container that still re-merges (PHT, a parent/child chain)
CDEObservationDomain(container: container, preciseRouteEchoSuppression: .on)

// .off: the store never re-merges its own saves
CDEObservationDomain(container: container, preciseRouteEchoSuppression: .off)
```

This is not CloudKit-specific: the suppression works from the `viewContext` merge notifications and
never inspects the merge source; `.auto` is only a default-on heuristic for the container most likely
to re-merge. It is separate from external-import precision below.

## Diagnostic Logging

Observation diagnostic logging is off by default. Enable it per process with
`CDE_OBSERVATION_DEBUG=1` (also accepts `true`, `yes`, and `on`) or toggle
`domain.isDebugLoggingEnabled` while investigating a retained domain.

Logs are emitted through unified logging with subsystem `CoreDataEvolution` and category
`Observation`, not through standard output. The public contract is the opt-in Boolean switch and the
environment variable; individual message text, timing fields, object summaries, and notification
userInfo-key summaries are diagnostic details and may change between releases.

## Limits To Keep In Mind

- This is not a universal Core Data observation system.
- CDE does not read Persistent History Tracking transactions; it routes from merge notifications.
- Changes imported from *other* devices (CloudKit) carry no changed keys, so they fall back to all
  observable key paths. A *local* save's precision is preserved across the store's own re-merge (see
  Precision Across Store Re-merges).
- Generated setters do not provide immediate unsaved refresh.
- To-many relationship setters are still not generated; use the generated relationship helper methods.
- Keep all UI reads and domain lifecycle operations on MainActor.

## Related Guides

- [PersistentModelGuide.md](./PersistentModelGuide.md)
- [NSModelActorGuide.md](./NSModelActorGuide.md)
- [TypedPathGuide.md](./TypedPathGuide.md)
