# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- **AGENTS.md pre-commit documentation check**: Agents are now prompted to reflect on whether they've discovered new codebase knowledge before every commit, and to update or create `AGENTS.md` files accordingly.

## [0.4.0] - 2026-02-15

### Added

- **`ListAccessory.toggle`**: Inline `UISwitch` accessory for settings screens with `isOn` binding and `onChange` callback.
- **`ListAccessory.badge`**: Pill-shaped count/status badge via `BadgeLabel` subclass with tint color propagation.
- **`ListAccessory.image`**: SF Symbol trailing icon accessory with debug assertions for invalid symbol names.
- **`ListAccessory.progress`**: Small inline progress bar (60pt width) with out-of-range value assertions.
- **`ListAccessory.activityIndicator`**: Spinning indicator accessory for loading states.

### Changed

- **`ListAccessory.uiAccessory`** is now `@MainActor`-isolated for UIKit thread safety.

## [0.3.0] - 2026-02-15

### Added

- **Scroll view delegate forwarding**: `SimpleList`, `GroupedList`, and `OutlineList` now forward `UIScrollViewDelegate` callbacks so consumers can receive scroll events without replacing the collection view's delegate.
- **`collectionViewHandler` and `scrollViewDelegate` parameters** added to `GroupedListView` and `OutlineListView` for API parity with `SimpleListView`.
- **`selfSizingInvalidation` parameter** on `SimpleList` and `SimpleListView` for controlling cell resize behavior during streaming content.
- **Chat example**: New `ChatExampleView` demonstrating streaming chat with manual layout invalidation, scroll-to-bottom tracking, and bubble-scoped context menus.

## [0.2.0] - 2026-02-15

### Added

- **`onDelete` callback**: Automatic trailing swipe action generation for item deletion across all list configurations.
- **`onMove` with drag-and-drop reorder**: Full drag-and-drop reorder infrastructure on `SimpleList` and `GroupedList` with `canMoveItemHandler` and `didMoveItemHandler` callbacks.
- **`onDeselect` callback**: Multi-selection deselection support forwarded through all SwiftUI wrappers.
- **`showsSeparators` parameter**: Native UIKit separator visibility toggle on all list configurations and `LayoutHelpers` factory methods.
- **`ListAccessory.label`**: Text label accessory case.
- **`ListAccessory.detail`**: Detail accessory with optional action handler.
- **`ListAccessory.multiselect`**: Multi-selection checkmark accessory.
- **`ListAccessory.popUpMenu`**: Pop-up menu accessory.
- **UICollectionLayoutListConfiguration support**: `separatorColor`, `backgroundColor`, `headerTopPadding` across all list types with `separatorHandler` for per-item separator customization.
- **Header/footer configuration**: `headerMode`/`footerMode` and `headerContentProvider`/`footerContentProvider` on `GroupedList`.
- **Selection APIs**: `allowsMultipleSelection`, `allowsSelectionDuringEditing`, `allowsMultipleSelectionDuringEditing`, and `isEditing` computed property on all list types.
- **Navigation APIs**: `itemIdentifier(for:)`, `indexPath(for:)`, and `scrollToItem(_:)` on all list configurations.
- **`GroupedList.setSections` with `SnapshotBuilder` DSL** for declarative section updates.
- **`ListLayout` factory methods** for all compositional layout appearance styles.
- **`dismantleUIView`** added to all SwiftUI wrappers for deterministic cleanup.
- **`buildLimitedAvailability`** added to all four result builders.
- **`withTaskCancellationHandler`** support to propagate cancellation from structured parent tasks during SwiftUI coordinator teardown.

### Changed

- **`SectionModel` `Item` constraint** relaxed to `Hashable & Sendable`, fixing inline-content convenience initializers for plain data types.
- **`SwipeActionBridge` renamed to `ListConfigurationBridge`**: Centralizes shared delegate logic, item navigation, and scroll-to-item into a single bridge to eliminate duplication across list types.
- **Rapid-render coalescing**: New updates now cancel previous pending applies for faster UI convergence.
- **UIKit layout closures** wrapped in `MainActor.assumeIsolated` for Swift 6 strict concurrency readiness.
- **`OutlineList.setItems`** now uses native section snapshot apply instead of flat snapshot rebuild, enabling UIKit's optimized subtree diffing and native expand/collapse animations.

### Fixed

- **Section snapshot parent map corruption**: Fixed `snapshot(of:includingParent:)` where dangling parent references were copied for extracted subtrees.
- **Multi-selection**: Guard `deselectItem` behind `!allowsMultipleSelection` so multi-selection workflows function correctly.
- **Snapshot/UI mismatch**: Serialized `applySnapshotUsingReloadData` through the apply task chain to prevent interleaving with animated applies.
- **Stale snapshot on deallocation**: Always update `currentSnapshot` before the `guard` when `collectionView` is deallocated.
- **GroupedList header/footer atomicity**: Use merge-then-trim pattern during animated transitions.
- **Snapshot data loss in move operation**: Validate destination section bounds before deleting item in `moveItemAt`.
- **`deinit` task cancellation** added to `SimpleList`, `GroupedList`, and `OutlineList` to cancel lingering tasks on deallocation.
- **Refresh control cleanup**: Use `defer` in `handleRefresh` to ensure `refreshTask` cleanup and spinner dismissal run on all exit paths.

### Performance

- **LIS-based minimal move detection**: Replaced naive diff move detection with longest-increasing-subsequence algorithm using O(n log n) patience sorting, eliminating unnecessary batch update animations.

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
