import SwiftUI
import UIKit

// MARK: - OutlineListView

/// A SwiftUI wrapper around ``OutlineList`` for displaying hierarchical outline lists.
///
/// Supports selection, swipe actions, context menus, and pull-to-refresh. Also provides
/// an inline content initializer that accepts a `@ViewBuilder`.
@MainActor
public struct OutlineListView<Item: CellViewModel>: UIViewRepresentable {

  // MARK: Lifecycle

  public init(
    items: [OutlineItem<Item>],
    appearance: UICollectionLayoutListConfiguration.Appearance = .sidebar,
    showsSeparators: Bool = true,
    onSelect: (@MainActor (Item) -> Void)? = nil,
    onDeselect: (@MainActor (Item) -> Void)? = nil,
    onDelete: (@MainActor (Item) -> Void)? = nil,
    trailingSwipeActionsProvider: (@MainActor (Item) -> UISwipeActionsConfiguration?)? = nil,
    leadingSwipeActionsProvider: (@MainActor (Item) -> UISwipeActionsConfiguration?)? = nil,
    contextMenuProvider: (@MainActor (Item) -> UIContextMenuConfiguration?)? = nil,
    onRefresh: (@MainActor () async -> Void)? = nil
  ) {
    self.items = items
    self.appearance = appearance
    self.showsSeparators = showsSeparators
    self.onSelect = onSelect
    self.onDeselect = onDeselect
    self.onDelete = onDelete
    self.trailingSwipeActionsProvider = trailingSwipeActionsProvider
    self.leadingSwipeActionsProvider = leadingSwipeActionsProvider
    self.contextMenuProvider = contextMenuProvider
    self.onRefresh = onRefresh
  }

  // MARK: Public

  @MainActor
  public final class Coordinator {

    // MARK: Lifecycle

    deinit {
      updateTask?.cancel()
      refreshTask?.cancel()
    }

    // MARK: Internal

    var list: OutlineList<Item>?
    var previousItems: [OutlineItem<Item>]?
    var updateTask: Task<Void, Never>?
    var onRefresh: (@MainActor () async -> Void)?

    @objc
    func handleRefresh(_ sender: UIRefreshControl) {
      guard refreshTask == nil else { return }
      refreshTask = Task { @MainActor in
        await onRefresh?()
        sender.endRefreshing()
        refreshTask = nil
      }
    }

    // MARK: Private

    private var refreshTask: Task<Void, Never>?

  }

  /// The hierarchical items to display.
  public let items: [OutlineItem<Item>]
  /// The visual appearance of the list.
  public let appearance: UICollectionLayoutListConfiguration.Appearance
  /// Whether separators are shown between rows.
  public let showsSeparators: Bool
  /// Called when the user taps an item.
  public var onSelect: (@MainActor (Item) -> Void)?
  /// Called when the user deselects an item (relevant when `allowsMultipleSelection` is enabled).
  public var onDeselect: (@MainActor (Item) -> Void)?
  /// Called when the user swipe-deletes an item. When set and ``trailingSwipeActionsProvider``
  /// is `nil`, a trailing destructive "Delete" swipe action is provided automatically.
  public var onDelete: (@MainActor (Item) -> Void)?
  /// Closure that returns trailing swipe actions for a given item.
  public var trailingSwipeActionsProvider: (@MainActor (Item) -> UISwipeActionsConfiguration?)?
  /// Closure that returns leading swipe actions for a given item.
  public var leadingSwipeActionsProvider: (@MainActor (Item) -> UISwipeActionsConfiguration?)?
  /// Closure that returns a context menu configuration for a given item.
  public var contextMenuProvider: (@MainActor (Item) -> UIContextMenuConfiguration?)?
  /// An async closure invoked on pull-to-refresh.
  public var onRefresh: (@MainActor () async -> Void)?

  public static func dismantleUIView(_: UICollectionView, coordinator: Coordinator) {
    coordinator.updateTask?.cancel()
    coordinator.updateTask = nil
    coordinator.list = nil
  }

  public func makeUIView(context: Context) -> UICollectionView {
    let list = OutlineList<Item>(appearance: appearance, showsSeparators: showsSeparators)
    list.onSelect = onSelect
    list.onDeselect = onDeselect
    list.onDelete = onDelete
    list.trailingSwipeActionsProvider = trailingSwipeActionsProvider
    list.leadingSwipeActionsProvider = leadingSwipeActionsProvider
    list.contextMenuProvider = contextMenuProvider
    context.coordinator.list = list
    context.coordinator.previousItems = items
    context.coordinator.onRefresh = onRefresh

    configureRefreshControl(
      on: list.collectionView,
      onRefresh: onRefresh,
      target: context.coordinator,
      action: #selector(Coordinator.handleRefresh(_:))
    )

    context.coordinator.updateTask = Task {
      await list.setItems(items, animatingDifferences: false)
    }
    return list.collectionView
  }

  public func updateUIView(_ collectionView: UICollectionView, context: Context) {
    guard let list = context.coordinator.list else { return }
    list.onSelect = onSelect
    list.onDeselect = onDeselect
    list.onDelete = onDelete
    list.trailingSwipeActionsProvider = trailingSwipeActionsProvider
    list.leadingSwipeActionsProvider = leadingSwipeActionsProvider
    list.contextMenuProvider = contextMenuProvider
    context.coordinator.onRefresh = onRefresh

    configureRefreshControl(
      on: collectionView,
      onRefresh: onRefresh,
      target: context.coordinator,
      action: #selector(Coordinator.handleRefresh(_:))
    )

    guard items != context.coordinator.previousItems else { return }
    context.coordinator.previousItems = items
    context.coordinator.updateTask?.cancel()
    context.coordinator.updateTask = Task {
      await list.setItems(items)
    }
  }

  public func makeCoordinator() -> Coordinator {
    Coordinator()
  }

}

// MARK: - Inline Content Convenience

extension OutlineListView {
  public init<Data: Hashable & Sendable>(
    items: [OutlineItem<Data>],
    appearance: UICollectionLayoutListConfiguration.Appearance = .sidebar,
    showsSeparators: Bool = true,
    accessories: [ListAccessory] = [],
    onSelect: (@MainActor (Data) -> Void)? = nil,
    onDeselect: (@MainActor (Data) -> Void)? = nil,
    onDelete: (@MainActor (Data) -> Void)? = nil,
    trailingSwipeActionsProvider: (@MainActor (Data) -> UISwipeActionsConfiguration?)? = nil,
    leadingSwipeActionsProvider: (@MainActor (Data) -> UISwipeActionsConfiguration?)? = nil,
    contextMenuProvider: (@MainActor (Data) -> UIContextMenuConfiguration?)? = nil,
    onRefresh: (@MainActor () async -> Void)? = nil,
    @ViewBuilder content: @escaping @MainActor (Data) -> some View
  ) where Item == InlineCellViewModel<Data> {
    let mapped = items.map { $0.mapItems { InlineCellViewModel(data: $0, accessories: accessories, content: content) } }

    self.items = mapped
    self.appearance = appearance
    self.showsSeparators = showsSeparators
    self.onRefresh = onRefresh

    if let onSelect {
      self.onSelect = { item in onSelect(item.data) }
    }
    if let onDeselect {
      self.onDeselect = { item in onDeselect(item.data) }
    }
    if let onDelete {
      self.onDelete = { item in onDelete(item.data) }
    }
    if let trailingSwipeActionsProvider {
      self.trailingSwipeActionsProvider = { item in trailingSwipeActionsProvider(item.data) }
    }
    if let leadingSwipeActionsProvider {
      self.leadingSwipeActionsProvider = { item in leadingSwipeActionsProvider(item.data) }
    }
    if let contextMenuProvider {
      self.contextMenuProvider = { item in contextMenuProvider(item.data) }
    }
  }
}
