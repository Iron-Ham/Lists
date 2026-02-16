# ListKit Module — Agent Instructions

> `CLAUDE.md` is a symlink to this file. Always edit `AGENTS.md`.

## Module Purpose

ListKit is the low-level diffing and data source engine. It provides:

- A fast O(n) Heckel diff algorithm
- `DiffableDataSourceSnapshot` — a value-type replacement for Apple's `NSDiffableDataSourceSnapshot`
- `DiffableDataSourceSectionSnapshot` — hierarchical parent-child snapshot
- `CollectionViewDiffableDataSource` — API-compatible replacement for `UICollectionViewDiffableDataSource`

This module has **zero dependencies** beyond UIKit/Foundation.

## Directory Structure

```
ListKit/
├── Algorithm/
│   ├── HeckelDiff.swift          — O(n) diff producing inserts/deletes/moves
│   ├── SectionedDiff.swift       — Per-section diffing with cross-section move reconciliation
│   └── StagedChangeset.swift     — Batches changes into safe UICollectionView update groups
├── DataSource/
│   └── CollectionViewDiffableDataSource.swift — Drop-in replacement for Apple's diffable data source
├── Snapshot/
│   ├── DiffableDataSourceSnapshot.swift        — Flat snapshot (sections + items)
│   └── DiffableDataSourceSectionSnapshot.swift — Hierarchical snapshot (parent-child trees)
└── ListKit.docc/                 — DocC documentation catalog
```

## Key Design Decisions

- **Parallel array storage**: Snapshots store `sectionIdentifiers: [SectionIdentifierType]` and `sectionItemArrays: [[ItemIdentifierType]]` as parallel arrays, with a `sectionIndex` dictionary for O(1) section-to-position lookups. This avoids Foundation overhead.
- **Lazy reverse map**: The `sectionIndex` dictionary (section ID → position) is eagerly rebuilt on section mutations. The `_itemToSection` reverse map (item → containing section) is built lazily on first use by mutation methods, avoiding construction cost in the common build-then-diff path.
- **Staged changesets**: `StagedChangeset` groups all computed diffs (section/item deletes, inserts, moves, reloads, reconfigures) into a single value type. `CollectionViewDiffableDataSource.performApply()` applies these in the correct order within `performBatchUpdates` to satisfy UICollectionView's constraints.
- **Generic constraints**: `SectionIdentifierType: Hashable & Sendable`, `ItemIdentifierType: Hashable & Sendable`.

## Performance

**Performance is the #1 priority for this module.** ListKit exists because Apple's implementation is too slow. Every change must preserve or improve performance.

Current baselines:
- Snapshot construction is ~752x faster than Apple's `NSDiffableDataSourceSnapshot`
- Diff computation is ~2.8x faster than IGListKit at 10k items
- The Heckel algorithm is O(n) average case (vs unknown complexity for Apple's diff)

Benchmarks live in `Tests/Benchmarks/`.

### Performance workflow

Any change that could affect performance **must**:
1. Run `make benchmark` before and after the change
2. Compare results to confirm no regression
3. Update the README with new numbers if baselines change

Do not merge changes that regress benchmark numbers without explicit approval.

## When Modifying This Module

- Changes to the diff algorithm must not break `StagedChangeset` output ordering
- Snapshot mutations must invalidate lazy index caches
- All public types must conform to `Sendable`
- `CollectionViewDiffableDataSource` must remain API-compatible with Apple's `UICollectionViewDiffableDataSource`
- Run `make test-listkit` to verify correctness
- Run `make benchmark` to verify performance (see Performance section above)
