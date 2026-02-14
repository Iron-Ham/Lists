# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-02-13

### Added

- **SwiftUI wrappers**: `SimpleListView`, `GroupedListView`, and `OutlineListView` — `UIViewRepresentable` wrappers driven by `@State`.
- **Inline content API**: `@ViewBuilder` convenience initializers on all three SwiftUI wrappers. Define cell content inline without creating a dedicated `CellViewModel` type.
- **`SwiftUICellViewModel` protocol**: Protocol for reusable SwiftUI-based cell view models with `body` and `accessories`.
- **`InlineCellViewModel`**: Type-erased `CellViewModel` backing the inline content API.
- **`ListAccessory`**: Pure-Swift enum wrapping `UICellAccessory` with a `.custom` escape hatch.
- **Swipe actions**: Leading and trailing swipe action support on all three list configurations and their SwiftUI wrappers.
- **Context menus**: Context menu support on all three list configurations and their SwiftUI wrappers.
- **Pull-to-refresh**: `onRefresh` async closure on all three SwiftUI wrappers with automatic `UIRefreshControl` lifecycle management.
- **`OutlineItem.mapItems`**: Recursive tree transformation for mapping data types across outline hierarchies.
- **`OutlineItem` `Equatable` conformance**: Enables diffing in SwiftUI `updateUIView`.

### Changed

- **`OutlineItem` generic constraint** relaxed from `CellViewModel` to `Hashable & Sendable`, enabling use with plain data types.
- **`SwiftUICellViewModel.accessories`** return type changed from `[UICellAccessory]` to `[ListAccessory]`.
- **Task serialization** added to `SimpleList.setItems`, `GroupedList.setSections`, and `OutlineList.setItems` to prevent concurrent snapshot applies.
- **Supplementary view bounds checking** added to `GroupedList` header/footer registration.

## [0.0.1] - 2025-12-20

Initial development release.

### Added

- **ListKit**: O(n) Heckel diff engine, `DiffableDataSourceSnapshot`, `DiffableDataSourceSectionSnapshot`, `CollectionViewDiffableDataSource`.
- **Lists**: `CellViewModel` protocol, `ListDataSource`, `MixedListDataSource`, `AnyItem`, result-builder DSL (`SnapshotBuilder`, `ItemsBuilder`, `MixedSnapshotBuilder`), `SimpleList`, `GroupedList`, `OutlineList` configurations, layout helpers.
- Swift 6 strict concurrency support.
- MIT license.
