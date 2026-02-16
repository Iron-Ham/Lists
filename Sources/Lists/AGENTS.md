# Lists Module — Agent Instructions

> `CLAUDE.md` is a symlink to this file. Always edit `AGENTS.md`.

## Module Purpose

Lists is the high-level, developer-facing API built on top of ListKit. It provides:

- **`CellViewModel` protocol** — the core abstraction tying cell content to diffable identity
- **Data sources** — `ListDataSource` (single type) and `MixedListDataSource` (heterogeneous)
- **Result builder DSL** — `@SnapshotBuilder`, `@ItemsBuilder`, `@MixedSnapshotBuilder`
- **Pre-built configurations** — `SimpleList`, `GroupedList`, `OutlineList`
- **SwiftUI wrappers** — `SimpleListView`, `GroupedListView`, `OutlineListView`
- **Accessories** — `ListAccessory` enum mapping to `UICellAccessory`

## Directory Structure

```
Lists/
├── Protocols/
│   ├── CellViewModel.swift          — Core protocol: Hashable + Sendable + cell configuration
│   └── SectionModel.swift           — Section metadata (header/footer text)
├── DataSource/
│   ├── ListDataSource.swift         — Single-cell-type data source with automatic registration
│   └── MixedListDataSource.swift    — Heterogeneous cell types via AnyItem type erasure
├── Builder/
│   ├── SnapshotBuilder.swift        — @resultBuilder for single-type snapshots
│   ├── ItemsBuilder.swift           — @resultBuilder for items within sections
│   ├── MixedSnapshotBuilder.swift   — @resultBuilder for mixed-type snapshots (also defines MixedItemsBuilder and MixedSection)
│   ├── DiffableDataSourceSnapshot+DSL.swift      — DSL extensions on Snapshot
│   └── DiffableDataSourceSnapshot+MixedDSL.swift — Mixed DSL extensions
├── Mixed/
│   └── AnyItem.swift                — Type-erased CellViewModel wrapper (measured overhead)
├── Configurations/
│   ├── SimpleList.swift             — Single-section flat list
│   ├── GroupedList.swift            — Multi-section with headers/footers
│   ├── OutlineList.swift            — Hierarchical expand/collapse
│   └── ListConfigurationBridge.swift — Shared configuration logic
├── SwiftUI/
│   ├── SimpleListView.swift         — SwiftUI wrapper for SimpleList
│   ├── GroupedListView.swift        — SwiftUI wrapper for GroupedList
│   ├── OutlineListView.swift        — SwiftUI wrapper for OutlineList
│   ├── SwiftUICellViewModel.swift   — Protocol adding SwiftUI body + accessories
│   ├── InlineCellViewModel.swift    — Type-erased inline SwiftUI content
│   └── ListAccessory.swift          — Pure-Swift enum for UICellAccessory
├── Extensions/
│   ├── CellViewModel+Identifiable.swift   — Default Hashable/Equatable from id
│   ├── LayoutHelpers.swift                — UICollectionLayoutListConfiguration shortcuts
│   └── RefreshControlConfiguration.swift  — Pull-to-refresh support
└── Lists.docc/                      — DocC documentation catalog
```

## Key Patterns

### CellViewModel Protocol

The single most important type in this module. A `CellViewModel` must:
1. Conform to `Hashable` and `Sendable`
2. Declare an associated `Cell` type (a `UICollectionViewCell` subclass)
3. Implement `func configure(_ cell: Cell)` to bind data to the cell

The default `Hashable`/`Equatable` implementations derive from `id`, provided by the `CellViewModel+Identifiable.swift` extension. Override only when content-based equality is needed.

### Result Builder DSL

The builders allow declarative snapshot construction:
```swift
dataSource.apply {
  SnapshotSection("favorites") {
    for item in favorites { item }
  }
  if showRecents {
    SnapshotSection("recents") {
      for item in recents { item }
    }
  }
}
```

`@SnapshotBuilder` and `@MixedSnapshotBuilder` are top-level; `@ItemsBuilder` and `@MixedItemsBuilder` are used inside sections.

### SwiftUI Integration

SwiftUI wrappers use `UIViewRepresentable`. The `SwiftUICellViewModel` protocol extends `CellViewModel` with a SwiftUI `body` and optional `accessories`. `InlineCellViewModel` is the type-erased version for inline closures.

### Mixed vs Single-Type

- `ListDataSource<Item>` — fastest path, no type erasure
- `MixedListDataSource` — wraps items in `AnyItem`, has measured overhead (~15-30%)
- Prefer single-type unless the list truly has heterogeneous cell types

## Critical Patterns

### Task Serialization (`applyTask` chain)

Any method that calls `await dataSource.apply(...)` **must** participate in the `applyTask` serialization chain. `@MainActor` does not prevent interleaving — `await` creates suspension points where other `@MainActor` code can run. Without serialization, overlapping applies corrupt snapshot state or header/footer dictionaries.

The pattern (used in `GroupedList.setSections`, `OutlineList.setItems`/`expand`/`collapse`, `MixedListDataSource.apply(content:)`):

```swift
applyTask?.cancel()
let previousTask = applyTask
let task = Task { [weak self] in
  _ = await previousTask?.value          // wait for previous to finish
  guard !Task.isCancelled, let self else { return }
  // ... build snapshot, merge headers ...
  await apply(snapshot, animatingDifferences: animatingDifferences)
  // ... trim headers ...
}
applyTask = task
await withTaskCancellationHandler {
  await task.value
} onCancel: {
  task.cancel()
}
```

If you add a new `async` method that applies snapshots, **you must use this pattern**.

### Header/Footer Merge-Then-Trim

When storing supplementary text (headers/footers) in dictionaries keyed by section ID, use the merge-then-trim strategy around animated applies:

1. **Merge** new values into existing dictionaries *before* applying the snapshot — ensures both old (animating out) and new sections resolve valid text during the transition
2. **Trim** to only new values *after* the apply completes — prevents stale entries from leaking

This pattern exists in `GroupedList.setSections` and `MixedListDataSource.apply(content:)`.

### API Surface Duplication Across Configurations

Convenience properties like `numberOfItems`, `numberOfSections`, `selectedItems`, `deselectAll`, and `UIScrollViewDelegate` forwarding are copy-pasted identically across `SimpleList`, `GroupedList`, and `OutlineList`. When adding a new convenience property or method to one configuration, **you must add it to all three** (plus their SwiftUI wrappers and modifier files if applicable). There is currently no shared protocol enforcing this — it's manual.

## When Modifying This Module

- New `CellViewModel` features must work with both `ListDataSource` and `MixedListDataSource`
- Result builders must support `if`/`else`, `for`, and `Optional` in all positions
- SwiftUI wrappers must call `updateUIView` correctly (avoid unnecessary reloads)
- All configurations are `@MainActor` — don't break actor isolation
- Any new `async` method that applies snapshots must use the `applyTask` serialization chain (see above)
- Run `make test-lists` to verify changes
- Run `make docs` if you changed any public API, doc comments (`///`), or files under `Lists.docc/` — commit the updated `docs/` output
