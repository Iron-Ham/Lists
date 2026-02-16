import SwiftUI
import UIKit

// MARK: - SimpleListView

/// A SwiftUI wrapper around ``SimpleList`` for displaying a flat list of items.
///
/// Supports selection, swipe actions, context menus, and pull-to-refresh. Also provides
/// an inline content initializer that accepts a `@ViewBuilder` for quick prototyping
/// without defining a ``CellViewModel``.
@MainActor
public struct SimpleListView<Item: CellViewModel>: UIViewRepresentable {

  // MARK: Lifecycle

  /// Creates a simple list view with layout configuration.
  ///
  /// Use chained modifiers for behavioral configuration:
  /// ```swift
  /// SimpleListView(items: contacts, appearance: .insetGrouped)
  ///     .onSelect { contact in navigateTo(contact) }
  ///     .onDelete { contact in remove(contact) }
  ///     .onRefresh { await reload() }
  /// ```
  public init(
    items: [Item],
    appearance: UICollectionLayoutListConfiguration.Appearance = .plain,
    showsSeparators: Bool = true,
    separatorColor: UIColor? = nil,
    backgroundColor: UIColor? = nil,
    headerTopPadding: CGFloat? = nil,
    selfSizingInvalidation: UICollectionView.SelfSizingInvalidation = .enabled
  ) {
    self.items = items
    self.appearance = appearance
    self.showsSeparators = showsSeparators
    self.separatorColor = separatorColor
    self.backgroundColor = backgroundColor
    self.headerTopPadding = headerTopPadding
    self.selfSizingInvalidation = selfSizingInvalidation
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

    var list: SimpleList<Item>?
    var previousItems: [Item]?
    var updateTask: Task<Void, Never>?
    var onRefresh: (@MainActor () async -> Void)?

    // Layout-immutable properties captured at creation time for debug validation.
    var initialAppearance: UICollectionLayoutListConfiguration.Appearance?
    var initialShowsSeparators: Bool?
    var initialSeparatorColor: UIColor??
    var initialBackgroundColor: UIColor??
    var initialHeaderTopPadding: CGFloat??
    var initialSelfSizingInvalidation: UICollectionView.SelfSizingInvalidation?

    @objc
    func handleRefresh(_ sender: UIRefreshControl) {
      guard refreshTask == nil else { return }
      refreshTask = Task { @MainActor [weak self] in
        defer {
          sender.endRefreshing()
          self?.refreshTask = nil
        }
        await self?.onRefresh?()
      }
    }

    // MARK: Private

    private var refreshTask: Task<Void, Never>?

  }

  /// The items to display in the list.
  public let items: [Item]
  /// The visual appearance of the list (e.g., `.plain`, `.insetGrouped`).
  ///
  /// - Important: Applied only when the view is first created. Subsequent SwiftUI state
  ///   changes to this value will not update the existing collection view layout.
  public let appearance: UICollectionLayoutListConfiguration.Appearance
  /// Whether separators are shown between rows.
  ///
  /// - Important: Applied only when the view is first created. Subsequent SwiftUI state
  ///   changes to this value will not update the existing collection view layout.
  public let showsSeparators: Bool
  /// A global tint color applied to all item separators.
  ///
  /// - Important: Applied only when the view is first created. Subsequent SwiftUI state
  ///   changes to this value will not update the existing collection view layout.
  public let separatorColor: UIColor?
  /// An optional background color for the list.
  ///
  /// - Important: Applied only when the view is first created. Subsequent SwiftUI state
  ///   changes to this value will not update the existing collection view layout.
  public let backgroundColor: UIColor?
  /// Extra padding above each section header.
  ///
  /// - Important: Applied only when the view is first created. Subsequent SwiftUI state
  ///   changes to this value will not update the existing collection view layout.
  public let headerTopPadding: CGFloat?
  /// Controls how the collection view handles self-sizing invalidation.
  ///
  /// Use `.disabled` when cell content changes frequently (e.g. streaming text) to avoid
  /// animated resize bouncing. The list will perform non-animated reconfiguration passes instead.
  ///
  /// - Important: Applied only when the view is first created. Subsequent SwiftUI state
  ///   changes to this value will not update the existing collection view.
  public let selfSizingInvalidation: UICollectionView.SelfSizingInvalidation
  /// Whether the list allows multiple simultaneous selections.
  public var allowsMultipleSelection = false
  /// Whether selection is allowed during editing mode.
  public var allowsSelectionDuringEditing = false
  /// Whether multiple selection is allowed during editing mode.
  public var allowsMultipleSelectionDuringEditing = false
  /// Whether the list is in editing mode.
  public var isEditing = false
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
  /// Per-item separator customization handler.
  public var separatorHandler: (@MainActor (Item, UIListSeparatorConfiguration) -> UIListSeparatorConfiguration)?
  /// An async closure invoked on pull-to-refresh. The refresh control is dismissed when the closure returns.
  public var onRefresh: (@MainActor () async -> Void)?
  /// Called once when the underlying `UICollectionView` is created. Use this to store a reference
  /// for direct UIKit access (e.g. animated layout invalidation).
  public var collectionViewHandler: (@MainActor (UICollectionView) -> Void)?
  /// An optional delegate that receives `UIScrollViewDelegate` callbacks from the underlying
  /// collection view's scroll view.
  public var scrollViewDelegate: UIScrollViewDelegate?

  public static func dismantleUIView(_: UICollectionView, coordinator: Coordinator) {
    coordinator.updateTask?.cancel()
    coordinator.updateTask = nil
    coordinator.list = nil
  }

  public func makeUIView(context: Context) -> UICollectionView {
    let list = SimpleList<Item>(
      appearance: appearance,
      showsSeparators: showsSeparators,
      separatorColor: separatorColor,
      backgroundColor: backgroundColor,
      headerTopPadding: headerTopPadding,
      selfSizingInvalidation: selfSizingInvalidation
    )
    list.onSelect = onSelect
    list.onDeselect = onDeselect
    list.onDelete = onDelete
    list.trailingSwipeActionsProvider = trailingSwipeActionsProvider
    list.leadingSwipeActionsProvider = leadingSwipeActionsProvider
    list.contextMenuProvider = contextMenuProvider
    list.separatorHandler = separatorHandler
    list.scrollViewDelegate = scrollViewDelegate
    list.allowsMultipleSelection = allowsMultipleSelection
    list.allowsSelectionDuringEditing = allowsSelectionDuringEditing
    list.allowsMultipleSelectionDuringEditing = allowsMultipleSelectionDuringEditing
    list.isEditing = isEditing
    context.coordinator.list = list
    context.coordinator.previousItems = items
    context.coordinator.onRefresh = onRefresh
    context.coordinator.initialAppearance = appearance
    context.coordinator.initialShowsSeparators = showsSeparators
    context.coordinator.initialSeparatorColor = separatorColor
    context.coordinator.initialBackgroundColor = backgroundColor
    context.coordinator.initialHeaderTopPadding = headerTopPadding
    context.coordinator.initialSelfSizingInvalidation = selfSizingInvalidation

    configureRefreshControl(
      on: list.collectionView,
      onRefresh: onRefresh,
      target: context.coordinator,
      action: #selector(Coordinator.handleRefresh(_:))
    )

    context.coordinator.updateTask = Task {
      await list.setItems(items, animatingDifferences: false)
    }
    collectionViewHandler?(list.collectionView)
    return list.collectionView
  }

  public func updateUIView(_ collectionView: UICollectionView, context: Context) {
    guard let list = context.coordinator.list else {
      assertionFailure("Coordinator.list is nil during updateUIView — possible lifecycle issue")
      return
    }
    assertLayoutPropertiesUnchanged(context.coordinator)
    list.onSelect = onSelect
    list.onDeselect = onDeselect
    list.onDelete = onDelete
    list.trailingSwipeActionsProvider = trailingSwipeActionsProvider
    list.leadingSwipeActionsProvider = leadingSwipeActionsProvider
    list.contextMenuProvider = contextMenuProvider
    list.separatorHandler = separatorHandler
    list.scrollViewDelegate = scrollViewDelegate
    list.allowsMultipleSelection = allowsMultipleSelection
    list.allowsSelectionDuringEditing = allowsSelectionDuringEditing
    list.allowsMultipleSelectionDuringEditing = allowsMultipleSelectionDuringEditing
    list.isEditing = isEditing
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

  // MARK: Private

  private func assertLayoutPropertiesUnchanged(_ coordinator: Coordinator) {
    assert(
      coordinator.initialAppearance == appearance
        && coordinator.initialShowsSeparators == showsSeparators
        && coordinator.initialSeparatorColor == separatorColor
        && coordinator.initialBackgroundColor == backgroundColor
        && coordinator.initialHeaderTopPadding == headerTopPadding
        && coordinator.initialSelfSizingInvalidation == selfSizingInvalidation,
      "SimpleListView layout properties (appearance, showsSeparators, separatorColor, backgroundColor, headerTopPadding, selfSizingInvalidation) cannot be changed after creation — UICollectionLayoutListConfiguration is immutable once the layout is built"
    )
  }

}

// MARK: - Inline Content Convenience

extension SimpleListView {
  public init<Data: Hashable & Sendable>(
    items: [Data],
    appearance: UICollectionLayoutListConfiguration.Appearance = .plain,
    showsSeparators: Bool = true,
    separatorColor: UIColor? = nil,
    backgroundColor: UIColor? = nil,
    headerTopPadding: CGFloat? = nil,
    selfSizingInvalidation: UICollectionView.SelfSizingInvalidation = .enabled,
    accessories: [ListAccessory] = [],
    onSelect: (@MainActor (Data) -> Void)? = nil,
    onDeselect: (@MainActor (Data) -> Void)? = nil,
    onDelete: (@MainActor (Data) -> Void)? = nil,
    trailingSwipeActionsProvider: (@MainActor (Data) -> UISwipeActionsConfiguration?)? = nil,
    leadingSwipeActionsProvider: (@MainActor (Data) -> UISwipeActionsConfiguration?)? = nil,
    contextMenuProvider: (@MainActor (Data) -> UIContextMenuConfiguration?)? = nil,
    separatorHandler: (@MainActor (Data, UIListSeparatorConfiguration) -> UIListSeparatorConfiguration)? = nil,
    @ViewBuilder content: @escaping @MainActor (Data) -> some View
  ) where Item == InlineCellViewModel<Data> {
    let mapped = items.map { InlineCellViewModel(data: $0, accessories: accessories, content: content) }

    self.items = mapped
    self.appearance = appearance
    self.showsSeparators = showsSeparators
    self.separatorColor = separatorColor
    self.backgroundColor = backgroundColor
    self.headerTopPadding = headerTopPadding
    self.selfSizingInvalidation = selfSizingInvalidation

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
    if let separatorHandler {
      self.separatorHandler = { item, config in separatorHandler(item.data, config) }
    }
  }
}
