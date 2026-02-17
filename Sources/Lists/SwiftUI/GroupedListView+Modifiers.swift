// ABOUTME: SwiftUI-style chained modifiers for GroupedListView configuration.
// ABOUTME: Includes onMove, headerContentProvider, and footerContentProvider.
import UIKit

/// SwiftUI-style modifier API for ``GroupedListView``.
///
/// Instead of passing all configuration through the initializer, use chained modifiers
/// for behavioral properties while keeping layout properties in the init:
///
/// ```swift
/// GroupedListView(sections: sections, appearance: .insetGrouped)
///     .onSelect { item in navigateTo(item) }
///     .onDelete { item in remove(item) }
///     .headerContentProvider { sectionID in customHeader(for: sectionID) }
///     .onRefresh { await reload() }
/// ```
extension GroupedListView {

  /// Sets a handler called when the user taps an item.
  public func onSelect(_ handler: @escaping @MainActor (Item) -> Void) -> Self {
    var copy = self
    copy.onSelect = handler
    return copy
  }

  /// Sets a handler called when the user deselects an item.
  public func onDeselect(_ handler: @escaping @MainActor (Item) -> Void) -> Self {
    var copy = self
    copy.onDeselect = handler
    return copy
  }

  /// Enables multiple simultaneous selections.
  public func allowsMultipleSelection(_ enabled: Bool = true) -> Self {
    var copy = self
    copy.allowsMultipleSelection = enabled
    return copy
  }

  /// Controls whether the list is in editing mode.
  public func editing(_ isEditing: Bool) -> Self {
    var copy = self
    copy.isEditing = isEditing
    return copy
  }

  /// Controls whether selection is allowed during editing mode.
  public func allowsSelectionDuringEditing(_ enabled: Bool = true) -> Self {
    var copy = self
    copy.allowsSelectionDuringEditing = enabled
    return copy
  }

  /// Controls whether multiple selection is allowed during editing mode.
  public func allowsMultipleSelectionDuringEditing(_ enabled: Bool = true) -> Self {
    var copy = self
    copy.allowsMultipleSelectionDuringEditing = enabled
    return copy
  }

  /// Sets a handler called when the user reorders an item via drag-and-drop.
  ///
  /// The list updates its internal snapshot automatically; use this to persist the new order.
  /// Setting this enables the reorder interaction on the collection view.
  public func onMove(
    _ handler: @escaping @MainActor (_ source: IndexPath, _ destination: IndexPath) -> Void
  ) -> Self {
    var copy = self
    copy.onMove = handler
    return copy
  }

  /// Sets a handler called when the user swipe-deletes an item.
  ///
  /// When set and no trailing swipe actions provider is configured, a trailing destructive
  /// "Delete" action is provided automatically.
  public func onDelete(_ handler: @escaping @MainActor (Item) -> Void) -> Self {
    var copy = self
    copy.onDelete = handler
    return copy
  }

  /// Sets a closure that returns trailing swipe actions for a given item.
  public func trailingSwipeActions(
    _ provider: @escaping @MainActor (Item) -> UISwipeActionsConfiguration?
  ) -> Self {
    var copy = self
    copy.trailingSwipeActionsProvider = provider
    return copy
  }

  /// Sets a closure that returns leading swipe actions for a given item.
  public func leadingSwipeActions(
    _ provider: @escaping @MainActor (Item) -> UISwipeActionsConfiguration?
  ) -> Self {
    var copy = self
    copy.leadingSwipeActionsProvider = provider
    return copy
  }

  /// Sets a closure that returns a context menu configuration for a given item.
  public func contextMenu(
    _ provider: @escaping @MainActor (Item) -> UIContextMenuConfiguration?
  ) -> Self {
    var copy = self
    copy.contextMenuProvider = provider
    return copy
  }

  /// Sets a per-item separator customization handler.
  public func separatorHandler(
    _ handler: @escaping @MainActor (Item, UIListSeparatorConfiguration) -> UIListSeparatorConfiguration
  ) -> Self {
    var copy = self
    copy.separatorHandler = handler
    return copy
  }

  /// Sets a closure that returns a custom content configuration for section headers.
  public func headerContentProvider(
    _ provider: @escaping @MainActor (SectionID) -> UIContentConfiguration?
  ) -> Self {
    var copy = self
    copy.headerContentProvider = provider
    return copy
  }

  /// Sets a closure that returns a custom content configuration for section footers.
  public func footerContentProvider(
    _ provider: @escaping @MainActor (SectionID) -> UIContentConfiguration?
  ) -> Self {
    var copy = self
    copy.footerContentProvider = provider
    return copy
  }

  /// Sets an async handler invoked on pull-to-refresh.
  ///
  /// The refresh control is dismissed automatically when the closure returns.
  public func onRefresh(_ handler: @escaping @MainActor () async -> Void) -> Self {
    var copy = self
    copy.onRefresh = handler
    return copy
  }

  /// Sets a handler called once when the underlying `UICollectionView` is created.
  public func collectionViewHandler(
    _ handler: @escaping @MainActor (UICollectionView) -> Void
  ) -> Self {
    var copy = self
    copy.collectionViewHandler = handler
    return copy
  }

  /// Sets a delegate that receives `UIScrollViewDelegate` callbacks.
  public func scrollViewDelegate(_ delegate: UIScrollViewDelegate) -> Self {
    var copy = self
    copy.scrollViewDelegate = delegate
    return copy
  }

  /// Sets a closure that determines whether an item should be selectable.
  ///
  /// Return `false` to prevent the item from being selected.
  public func shouldSelect(_ handler: @escaping @MainActor (Item) -> Bool) -> Self {
    var copy = self
    copy.shouldSelect = handler
    return copy
  }

  /// Sets a view displayed behind the list content.
  ///
  /// The view is automatically shown when the list is empty and hidden when it has content.
  public func backgroundView(_ view: UIView) -> Self {
    var copy = self
    copy.backgroundView = view
    return copy
  }

  /// Sets a closure that determines whether a specific item can be reordered.
  ///
  /// When set alongside ``onMove(_:)``, this is called for each item when drag begins.
  /// Return `false` to prevent an item from being dragged.
  public func canMoveItem(
    _ provider: @escaping @MainActor (Item) -> Bool
  ) -> Self {
    var copy = self
    copy.canMoveItemProvider = provider
    return copy
  }
}
