# ListKit — Agent Instructions

> **This file is the source of truth.** `CLAUDE.md` is a symlink to this file.
> Agents should create and update `AGENTS.md` files (never edit `CLAUDE.md` directly — it's a symlink).
> When creating a new `AGENTS.md`, always create a corresponding `CLAUDE.md` symlink:
> `ln -s AGENTS.md CLAUDE.md`

## Project Overview

ListKit is a high-performance, type-safe UICollectionView framework for iOS, organized as two Swift modules in a single package:

- **ListKit** (`Sources/ListKit/`) — Low-level diffing engine. Drop-in replacement for `UICollectionViewDiffableDataSource` with an O(n) Heckel diff algorithm.
- **Lists** (`Sources/Lists/`) — High-level declarative API built on ListKit. Provides ViewModel-driven data sources, result-builder DSL, pre-built configurations, and SwiftUI wrappers.

Lists depends on ListKit. External consumers import either `ListKit` (low-level) or `Lists` (high-level; must also `import ListKit` separately if using its types directly).

## Architecture

```
SwiftUI Wrappers (SimpleListView, GroupedListView, OutlineListView)
        ↓
Pre-Built Configurations (SimpleList, GroupedList, OutlineList)
        ↓
Data Sources (ListDataSource, MixedListDataSource)
        ↓
Builder DSL + Protocols (CellViewModel, SnapshotBuilder, AnyItem)
        ↓
ListKit Core (Snapshot, HeckelDiff, SectionedDiff, CollectionViewDiffableDataSource)
```

## Build & Test

**Always use the Makefile** for building, testing, formatting, and other project tasks. The Makefile wraps complex `xcodebuild` invocations with the correct workspace, scheme, destination, and derived data paths. Do not invoke `xcodebuild` or `swift build` directly — use `make` targets instead.

| Command | Description |
|---|---|
| `make setup` | First-time setup (install Tuist, generate project, install hooks) |
| `make build` | Build both frameworks |
| `make test` | Run all tests |
| `make test-listkit` | Run ListKit tests only |
| `make test-lists` | Run Lists tests only |
| `make benchmark` | Run comparative benchmarks |
| `make format` | Format code with SwiftFormat |
| `make lint` | Lint code with SwiftFormat |
| `make docs` | Generate DocC documentation |
| `make open` | Open in Xcode |

Tests require an iOS Simulator destination. The Makefile defaults to `iPhone 17 Pro`.

## Code Style

- **Swift 6** strict concurrency — all public types must be `Sendable`
- **SwiftFormat** with Airbnb-based config (see `.swiftformat`)
  - 2-space indentation
  - Max line width: 130 (recommend ≤100)
  - `--self remove` (no explicit `self`)
  - Trailing commas on multi-element collections only
  - `organizeDeclarations` is enabled — declaration order matters
- Run `make format` before committing
- Run `make lint` to check without modifying

## Performance

**Performance is the #1 priority for the ListKit module.** ListKit exists because Apple's implementation is too slow — every change to `Sources/ListKit/` must preserve or improve performance.

Any change that could affect performance **must**:
1. Run `make benchmark` before and after the change
2. Compare results to confirm no regression
3. Update the README with new numbers if baselines change

Do not merge changes that regress benchmark numbers without explicit approval. See [`Sources/ListKit/AGENTS.md`](Sources/ListKit/AGENTS.md) for current baselines and details.

## Changelog

**ALL pull requests MUST include a changelog entry.** The project maintains a [`CHANGELOG.md`](CHANGELOG.md) following the [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format.

When submitting a PR:
1. Add an entry under the `## [Unreleased]` section at the top of `CHANGELOG.md` (create the section if it doesn't exist)
2. Use the appropriate subsection: `Added`, `Changed`, `Deprecated`, `Removed`, `Fixed`, or `Security`
3. Write a concise, user-facing description of the change
4. PRs without a changelog entry should not be merged

## Documentation

The project uses **DocC** to generate API documentation, hosted as static files in the `docs/` directory (checked into the repo). Run `make docs` to regenerate.

**You MUST run `make docs`** and commit the updated `docs/` output when any of the following change:

- **Public API** in `Sources/ListKit/` or `Sources/Lists/` — adding, removing, or renaming any `public` type, method, property, or protocol requirement
- **Doc comments** (`///`) on public symbols
- **DocC catalog content** — anything under `Sources/ListKit/ListKit.docc/` or `Sources/Lists/Lists.docc/` (articles, tutorials, media, symbol extensions)

If unsure whether your change affects generated docs, run `make docs` and check `git diff docs/` — if there are changes, include them in the commit.

## Key Conventions

- **`CellViewModel` protocol** is the core abstraction in Lists. Requires `Hashable` + `Sendable`. Optionally conform to `Identifiable` to get free `Hashable`/`Equatable` from `id`.
- **Value types everywhere** — snapshots, changesets, and section models are all structs.
- **No runtime introspection** — everything is resolved at compile time via generics and protocols.
- **`@MainActor` isolation** — data sources and configurations are `@MainActor`-bound.
- **Parallel array storage** — snapshots use a flat `[Section]` array alongside a parallel `[[Item]]` (items-per-section) array, avoiding dictionary overhead.

## File Organization

Each directory with an `AGENTS.md` has module-specific instructions:

- [`Sources/ListKit/AGENTS.md`](Sources/ListKit/AGENTS.md) — Diffing engine internals
- [`Sources/Lists/AGENTS.md`](Sources/Lists/AGENTS.md) — High-level API, SwiftUI, DSL
- [`Tests/AGENTS.md`](Tests/AGENTS.md) — Testing patterns and benchmarks
- [`Example/AGENTS.md`](Example/AGENTS.md) — Demo app conventions

## Updating These Instructions

Agents are **encouraged** to create and update `AGENTS.md` files as they learn about the codebase. When doing so:

1. Always edit `AGENTS.md` (never `CLAUDE.md` — it's a symlink)
2. When creating a new `AGENTS.md` in a subdirectory, also create the symlink:
   ```sh
   ln -s AGENTS.md CLAUDE.md
   ```
3. Keep instructions factual, concise, and specific to the directory's scope
4. Update instructions when code patterns change (e.g., new conventions, renamed types)
5. Don't duplicate information from parent `AGENTS.md` — child files inherit parent context

### Pre-Commit Documentation Check

**Before every commit**, pause and ask yourself:

> *Have I learned something new about this codebase — a convention, a gotcha, an architectural decision, a non-obvious dependency — that isn't already captured in an `AGENTS.md` file?*

If yes:
- **Update** the nearest relevant `AGENTS.md` with the new information
- **Create** a new `AGENTS.md` (+ `CLAUDE.md` symlink) in the directory where the knowledge is most scoped, if no suitable file exists yet
- Include the documentation update in the same commit as the code change

This ensures institutional knowledge grows naturally alongside the code, rather than being lost between sessions.
