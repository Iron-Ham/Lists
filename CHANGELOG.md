# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **`MixedSection` header/footer support**: Optional `header` and `footer` parameters on `MixedSection`, bringing parity with `SnapshotSection` for mixed-type lists.
- **`MixedListDataSource` reorder support**: `canMoveItemHandler` and `didMoveItemHandler` properties for drag-and-drop reordering parity with `ListDataSource`.
- **Section query methods on `GroupedList`**: `sectionIdentifier(for:)`, `index(for:)`, and `items(in:)` for section-level navigation.
- **`OutlineList` programmatic expand/collapse**: `expand(_:animated:)`, `collapse(_:animated:)`, and `isExpanded(_:)` methods for controlling outline hierarchy without rebuilding the tree.
- **`onMove` SwiftUI modifier**: `.onMove()` modifier on `SimpleListView` and `GroupedListView` for drag-and-drop reordering, completing the SwiftUI wrapper API.
- **Convenience query properties**: `numberOfItems`, `numberOfSections`, `selectedItems`, and `deselectAll(animated:)` on all three configurations (`SimpleList`, `GroupedList`, `OutlineList`).
- **`SectionModel.mapItems(_:)`**: Transforms items within a section while preserving metadata, matching `OutlineItem.mapItems(_:)` for API consistency.
- **`SectionModel` `Identifiable` conformance**: Enables direct use in SwiftUI `ForEach` and other `Identifiable`-requiring contexts.
- **`OutlineItem` `Identifiable` conformance**: Uses `item` as identity, enabling direct use in SwiftUI contexts.

## [0.5.0] - 2026-02-16

### Added

- **UIKit chat examples**: Two new UIKit counterparts to the existing SwiftUI chat example — `ListsChatExampleViewController` (`SimpleList` + `CellViewModel` + `UIHostingConfiguration`) and `ListKitChatExampleViewController` (raw `CollectionViewDiffableDataSource` with pure UIKit cells and manual cell reconfiguration).
- **Shared chat input bar**: Reusable `ChatInputBar` UIKit view with keyboard layout guide support.
- **`ListCellViewModel` protocol**: Convenience refinement of `CellViewModel` that defaults `Cell` to `UICollectionViewListCell`, eliminating the most common boilerplate `typealias`.
- **`UICollectionViewListCell.setListContent()` helpers**: Two convenience methods (parameter-based and closure-based) that replace the repetitive 4-line content configuration pattern with a single call.
- **SwiftUI-style view modifiers**: Chainable `.onSelect`, `.onDelete`, `.onRefresh`, `.editing`, `.contextMenu`, `.trailingSwipeActions`, `.leadingSwipeActions`, and more on `SimpleListView`, `GroupedListView`, and `OutlineListView`. Replaces the 19+ parameter initializer with an idiomatic init-then-modify pattern.
- **Pull-to-refresh on UIKit configurations**: `onRefresh` property on `SimpleList`, `GroupedList`, and `OutlineList` with proper async task lifecycle management, bringing parity with the SwiftUI wrappers.
- **`ContentEquatable` protocol**: Opt-in protocol for detecting content changes in identity-based view models. Automatically marks items for reconfiguration when content differs, solving the stale-UI footgun with `Identifiable` types.
- **`OutlineItemBuilder` result builder**: Declarative trailing-closure syntax for constructing `OutlineItem` hierarchies with full support for conditionals, loops, and arrays.
- **`SectionModel` `@ItemsBuilder` initializer**: Declarative builder-based section construction constrained to `CellViewModel` items.
- **`SnapshotSection` header/footer support**: `header` and `footer` optional parameters in the `SnapshotBuilder` DSL, wired through to `GroupedList.setSections`.
- **`Snapshot.contains(_:)` and `contains(section:)`**: Convenience queries using the reverse map for O(1) lookups when available.

### Changed

- **BREAKING: SwiftUI view initializers simplified**: `SimpleListView`, `GroupedListView`, and `OutlineListView` CellViewModel-based initializers now accept only layout/structural parameters. Behavioral properties (`onSelect`, `onDelete`, `onRefresh`, `editing`, etc.) must be set via the new chainable modifiers. Inline content initializers retain item-typed behavioral params (e.g., `onSelect`, `onDelete`) since they perform `Data → Item` wrapping.
- **Refresh control logic consolidated**: Extracted `RefreshControlManager` to replace triplicated refresh control code across `SimpleList`, `GroupedList`, and `OutlineList`.
- **Example app updated**: All UIKit examples use `ListCellViewModel` and `setListContent()`. `OutlineExampleViewController` uses builder DSL. `SwiftUIWrappersExampleView` demonstrates modifier-based configuration. `LiveExampleViewController` uses `ContentEquatable` for automatic reconfiguration.
- **Example app: expanded feature coverage**: DSL example uses `GroupedList` with `SnapshotSection` header/footer DSL and `Snapshot.contains(section:)`. GroupedList example demonstrates `@ItemsBuilder`, `ListAccessory.toggle`, `.progress`, and `.activityIndicator`. All three UIKit examples include pull-to-refresh. SwiftUI `GroupedDemoView` demonstrates `.editing` and `.allowsMultipleSelection` modifiers.

### Fixed

- **Chat example separators**: Added explicit `separatorHandler` to `ListsChatExampleViewController` to ensure separators are fully hidden, preventing `itemSeparatorHandler` from overriding `showsSeparators: false`.
- **Cell reuse accessory leak**: `setListContent()` now unconditionally assigns accessories, preventing stale accessories from persisting across cell reuse.
- **`ListAccessory.progress` crash**: Replaced `translatesAutoresizingMaskIntoConstraints = false` (which violates `UICellAccessory.customView` requirements) with `reservedLayoutWidth: .custom(60)`.

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
