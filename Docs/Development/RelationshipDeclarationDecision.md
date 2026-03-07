# Relationship Declaration Decision

## Status

Accepted for implementation.

## Context

`@PersistentModel` currently infers relationships from property types:

- `Tag?` -> to-one relationship
- `Set<Tag>` -> unordered to-many relationship
- `[Tag]` -> ordered to-many relationship

Additional relationship semantics are currently incomplete at the source level:

- source declarations do not require explicit relationship metadata
- delete rules are not declared in source
- runtime-only model building must reconstruct relationship behavior later

That leaves the relationship DSL split across multiple concepts and makes tooling/runtime
reconstruction more complex than necessary.

## Decision

Introduce a single public `@Relationship(...)` macro as the canonical relationship declaration.

Target source form:

```swift
@Relationship(inverse: "items", deleteRule: .nullify)
var tag: Tag?

@Relationship(inverse: "tag", deleteRule: .cascade)
var items: Set<Item>
```

## Canonical Rules

1. Every relationship property must be explicitly annotated with `@Relationship(...)`.
2. `inverse` is required.
3. `deleteRule` is required.
4. The property type still determines cardinality:
   - `Entity?` -> to-one
   - `Set<Entity>` -> unordered to-many
   - `[Entity]` -> ordered to-many
5. Optional to-many remains invalid.
6. Relationship properties remain stored instance `var` declarations only.
7. The system does not infer inverse names or delete rules from source declarations.

## Why This Direction

This produces a simpler and more stable source model:

- one place for all relationship metadata
- no public `@Inverse` concept
- no runtime inverse inference requirement in the common case
- no separate relationship comment contract
- generate/validate/exact can compare one canonical source shape
- self-referential and multiple-to-same-target relationships become ordinary explicit declarations

## Non-Goals

- The macro will not infer delete rules.
- The macro will not infer inverse names.
- The macro will not change cardinality derived from the property type.

## Delete Rule Policy

`deleteRule` must not have a source-level default.

Reason:

- `.cascade` is common in some parent-child models, but unsafe as a framework-level default.
- `.nullify` is Core Data's conservative default, but once relationship declarations are explicit,
  even `.nullify` should be written out instead of assumed.

Therefore the final source shape requires `deleteRule` to be written out on every relationship.

Supported source values are:

- `.nullify`
- `.cascade`
- `.deny`

`.noAction` is intentionally unsupported in v1 and must be rejected by macros and tooling.

## Runtime Schema Impact

Once `@Relationship(...)` is adopted, runtime schema should carry:

- inverse property name
- delete rule
- ordered/unordered kind
- optionality
- target type name

That removes the need for inverse inference for macro-generated runtime schema.

## Tooling Impact

`cde-tool generate`:

- must emit `@Relationship(...)` for every relationship property
- must carry inverse + delete rule from the source model
- must continue rejecting models that omit inverse configuration, matching the existing tooling rule
  that every model relationship must have an inverse before code generation

`cde-tool validate`:

- must compare source `@Relationship(...)` metadata against the model
- must reject missing `@Relationship(...)`

`cde-tool inspect`:

- should surface relationship metadata in the same canonical shape

## Replaced API

`@Inverse` is replaced by `@Relationship(...)`.

The public relationship surface should expose only one declaration form.

## Testing Impact

Tests should cover:

1. to-one relationship with explicit `@Relationship`
2. unordered and ordered to-many with explicit `@Relationship`
3. self-referential relationships
4. multiple relationships to the same target type
5. compile-time failure when `@Relationship(...)` is missing
6. runtime schema propagation of `inverse` and `deleteRule`
7. tooling generate/validate round-trip
