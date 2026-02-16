# Tests — Agent Instructions

> `CLAUDE.md` is a symlink to this file. Always edit `AGENTS.md`.

## Test Structure

```
Tests/
├── ListKitTests/       — Unit tests for the ListKit diffing engine
├── ListsTests/         — Unit + integration tests for the Lists high-level API
│   └── Helpers/
│       └── TestViewModels.swift  — Shared test fixtures
└── Benchmarks/         — Comparative performance benchmarks
```

## Running Tests

| Command | Scope |
|---|---|
| `make test` | All test targets |
| `make test-listkit` | ListKitTests only |
| `make test-lists` | ListsTests only |
| `make benchmark` | Benchmarks (Release config, ENABLE_TESTABILITY=YES) |

Tests run on iOS Simulator (`iPhone 17 Pro` by default).

## Test Conventions

- **Swift Testing** is the test framework (`import Testing`, `@Test`, `#expect`)
- Test containers are plain `struct`s (not `XCTestCase` subclasses)
- Test files mirror source file names: `HeckelDiff.swift` → `HeckelDiffTests.swift`
- Use descriptive camelCase method names: `func emptySnapshot()`, `func appendSections()`
- Shared fixtures live in `ListsTests/Helpers/TestViewModels.swift`
- Tests that require a `UICollectionView` create one inline with a layout — no storyboards

## Benchmarks

Benchmarks compare ListKit against:
- Apple's `NSDiffableDataSourceSnapshot`
- IGListKit's `IGListDiff`
- ReactiveCollectionsKit

Benchmarks run in **Release** configuration for accurate measurements. They use a custom `benchmark { }` helper (median-of-N with warmup) and `#expect` assertions to verify ListKit is faster.

## When Adding Tests

- Place ListKit (algorithm/snapshot/data source) tests in `ListKitTests/`
- Place Lists (CellViewModel/DSL/configuration/SwiftUI) tests in `ListsTests/`
- Reuse existing test helpers from `TestViewModels.swift` where possible
- New test ViewModels should be added to `TestViewModels.swift` if reusable
- Run the full suite (`make test`) before submitting changes
