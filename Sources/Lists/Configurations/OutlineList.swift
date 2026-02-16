import ListKit
import UIKit

// MARK: - OutlineItem

/// A node in a tree structure used by ``OutlineList`` to represent hierarchical data.
///
/// Each `OutlineItem` wraps a value and optionally has children. The `isExpanded` flag
/// controls whether children are visible when the outline is rendered.
public struct OutlineItem<Item: Hashable & Sendable>: Sendable, Equatable, Identifiable {

  // MARK: Lifecycle

  /// Creates an outline item with optional children and expansion state.
  public init(item: Item, children: [OutlineItem<Item>] = [], isExpanded: Bool = false) {
    self.item = item
    self.children = children
    self.isExpanded = isExpanded
  }

  // MARK: Public

  /// The data value for this node.
  public let item: Item
  /// The child nodes. Empty for leaf items.
  public let children: [OutlineItem<Item>]
  /// Whether this node's children should be visible.
  public let isExpanded: Bool

  /// The identity of this outline item, derived from its ``item`` value.
  public var id: Item {
    item
  }

  /// Recursively transforms every `item` in this tree using the given closure.
  public func mapItems<T: Hashable & Sendable>(_ transform: (Item) -> T) -> OutlineItem<T> {
    OutlineItem<T>(
      item: transform(item),
      children: children.map { $0.mapItems(transform) },
      isExpanded: isExpanded
    )
  }
}

// MARK: - OutlineList

/// A hierarchical outline list backed by a `UICollectionView` with section snapshots.
///
/// `OutlineList` uses ``DiffableDataSourceSectionSnapshot`` under the hood to model
/// parent–child relationships. Items can be expanded or collapsed.
///
/// - Note: Unlike ``SimpleList`` and ``GroupedList``, `OutlineList` does not support
///   drag-and-drop reordering (`onMove`) due to the complexity of hierarchical move
///   constraints. Use a flat list if reordering is required.
///
/// ## Layout Configuration
///
/// Layout properties (`appearance`, `showsSeparators`, `separatorColor`, `backgroundColor`,
/// `headerTopPadding`) are set during initialization and cannot be changed afterward.
/// This is a UIKit limitation — `UICollectionLayoutListConfiguration` is snapshot-immutable
/// once the layout is created. Dynamic properties like ``allowsMultipleSelection`` and
/// ``isEditing`` can be changed at any time.
///
/// ```swift
/// let list = OutlineList<FileItem>()
/// await list.setItems([
///     OutlineItem(item: folder, children: [
///         OutlineItem(item: file)
///     ], isExpanded: true)
/// ])
/// ```
@MainActor
public final class OutlineList<Item: CellViewModel>: NSObject, UICollectionViewDelegate {

  // MARK: Lifecycle

  deinit {
    applyTask?.cancel()
    refreshManager.cancel()
  }

  /// Creates an outline list with the specified list appearance.
  ///
  /// - Parameters:
  ///   - appearance: The visual style of the list (e.g., `.sidebar`, `.plain`, `.insetGrouped`).
  ///   - showsSeparators: Whether separators are shown between rows.
  ///   - separatorColor: A global tint color applied to all item separators. Per-item
  ///     customization via ``separatorHandler`` takes precedence.
  ///   - backgroundColor: An optional background color for the list. When `nil`, the system default is used.
  ///   - headerTopPadding: Extra padding above each section header. When `nil`, the system default is used.
  public init(
    appearance: UICollectionLayoutListConfiguration.Appearance = .sidebar,
    showsSeparators: Bool = true,
    separatorColor: UIColor? = nil,
    backgroundColor: UIColor? = nil,
    headerTopPadding: CGFloat? = nil
  ) {
    let bridge = ListConfigurationBridge<Int, Item>()
    self.bridge = bridge
    bridge.setDefaultSeparatorColor(separatorColor)

    var config = UICollectionLayoutListConfiguration(appearance: appearance)
    config.showsSeparators = showsSeparators
    if let backgroundColor {
      config.backgroundColor = backgroundColor
    }
    if let headerTopPadding {
      config.headerTopPadding = headerTopPadding
    }
    bridge.configure(&config)
    let layout = UICollectionViewCompositionalLayout.list(using: config)

    collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
    dataSource = ListDataSource(collectionView: collectionView)
    super.init()
    collectionView.delegate = self
    refreshManager.attach(to: collectionView)

    bridge.setDataSource(dataSource)
    // trailingSwipeActionsProvider takes precedence; onDelete is the fallback.
    bridge.setTrailingProvider { [weak self] item in
      guard let self else { return nil }
      if let config = trailingSwipeActionsProvider?(item) {
        return config
      }
      guard let onDelete else { return nil }
      let action = UIContextualAction(style: .destructive, title: String(localized: "Delete")) { _, _, completion in
        onDelete(item)
        completion(true)
      }
      return UISwipeActionsConfiguration(actions: [action])
    }
    bridge.setLeadingProvider { [weak self] item in self?.leadingSwipeActionsProvider?(item) }
  }

  // MARK: Public

  /// The underlying collection view. Add this to your view hierarchy.
  public let collectionView: UICollectionView
  /// Called when the user taps an item.
  public var onSelect: (@MainActor (Item) -> Void)?
  /// Called when the user deselects an item (relevant when `allowsMultipleSelection` is enabled).
  public var onDeselect: (@MainActor (Item) -> Void)?

  /// Called when the user swipe-deletes an item. When set and ``trailingSwipeActionsProvider``
  /// is `nil`, a trailing destructive "Delete" swipe action is provided automatically.
  ///
  /// - Important: The caller is responsible for removing the item from the data source
  ///   after this callback fires. The list does not automatically mutate its snapshot.
  ///
  /// - Note: The swipe action always completes as "performed" regardless of whether the
  ///   underlying operation succeeds. Ensure your handler updates the data source to
  ///   reflect the actual result.
  public var onDelete: (@MainActor (Item) -> Void)?

  /// Closure that returns trailing swipe actions for a given item.
  public var trailingSwipeActionsProvider: (@MainActor (Item) -> UISwipeActionsConfiguration?)?
  /// Closure that returns leading swipe actions for a given item.
  public var leadingSwipeActionsProvider: (@MainActor (Item) -> UISwipeActionsConfiguration?)?
  /// Closure that returns a context menu configuration for a given item.
  public var contextMenuProvider: (@MainActor (Item) -> UIContextMenuConfiguration?)?

  /// An optional delegate that receives `UIScrollViewDelegate` callbacks from the underlying
  /// collection view's scroll view.
  ///
  /// Use this to track scroll position, detect user-initiated drags, or respond to deceleration
  /// events without replacing the collection view's delegate (which the list manages internally).
  public weak var scrollViewDelegate: UIScrollViewDelegate?

  /// An async closure invoked on pull-to-refresh. The refresh control is dismissed
  /// automatically when the closure returns.
  ///
  /// ```swift
  /// list.onRefresh = {
  ///     let items = try? await api.fetchTree()
  ///     await list.setItems(items ?? [])
  /// }
  /// ```
  public var onRefresh: (@MainActor () async -> Void)? {
    didSet { refreshManager.onRefresh = onRefresh }
  }

  /// Per-item separator customization handler.
  ///
  /// Called for each item before display. Return a modified configuration to customize
  /// separator appearance (color, insets, visibility) on a per-item basis.
  ///
  /// ```swift
  /// list.separatorHandler = { item, defaultConfig in
  ///     var config = defaultConfig
  ///     config.color = .systemRed
  ///     config.bottomSeparatorInsets.leading = 16
  ///     return config
  /// }
  /// ```
  public var separatorHandler: (@MainActor (Item, UIListSeparatorConfiguration) -> UIListSeparatorConfiguration)? {
    didSet { bridge.setSeparatorProvider(separatorHandler) }
  }

  /// Whether the list allows multiple simultaneous selections.
  ///
  /// When `true`, tapping an item does not automatically deselect other items.
  /// Use ``onDeselect`` to track deselection events.
  public var allowsMultipleSelection: Bool {
    get { collectionView.allowsMultipleSelection }
    set { collectionView.allowsMultipleSelection = newValue }
  }

  /// Whether selection is allowed during editing mode.
  public var allowsSelectionDuringEditing: Bool {
    get { collectionView.allowsSelectionDuringEditing }
    set { collectionView.allowsSelectionDuringEditing = newValue }
  }

  /// Whether multiple selection is allowed during editing mode.
  public var allowsMultipleSelectionDuringEditing: Bool {
    get { collectionView.allowsMultipleSelectionDuringEditing }
    set { collectionView.allowsMultipleSelectionDuringEditing = newValue }
  }

  /// Whether the list is in editing mode.
  ///
  /// When `true`, cells may display editing controls such as delete and reorder accessories.
  public var isEditing: Bool {
    get { collectionView.isEditing }
    set { collectionView.isEditing = newValue }
  }

  /// The total number of items across all sections.
  public var numberOfItems: Int {
    dataSource.snapshot().numberOfItems
  }

  /// The number of sections in the list.
  public var numberOfSections: Int {
    dataSource.snapshot().numberOfSections
  }

  /// The currently selected items, derived from the collection view's selected index paths.
  public var selectedItems: [Item] {
    (collectionView.indexPathsForSelectedItems ?? []).compactMap { bridge.itemIdentifier(for: $0) }
  }

  /// Replaces the outline's tree, computing and animating the diff.
  ///
  /// Uses `apply(_:to:animatingDifferences:)` with a section snapshot so UIKit handles
  /// hierarchy natively — expand/collapse animations and optimized subtree diffing come
  /// for free instead of forcing a full flat diff on every update.
  ///
  /// Cancels any previously queued apply so only the most recent snapshot is applied,
  /// and supports cooperative cancellation from the calling task.
  public func setItems(_ items: [OutlineItem<Item>], animatingDifferences: Bool = true) async {
    applyTask?.cancel()
    let previousTask = applyTask
    let task = Task { [weak self] in
      _ = await previousTask?.value
      guard !Task.isCancelled, let self else { return }

      // Ensure the section exists before applying the section snapshot.
      var mainSnapshot = dataSource.snapshot()
      if mainSnapshot.numberOfSections == 0 {
        mainSnapshot.appendSections([0])
        await dataSource.apply(mainSnapshot, animatingDifferences: false)
        guard !Task.isCancelled else { return }
      }

      var sectionSnapshot = DiffableDataSourceSectionSnapshot<Item>()
      appendItems(items, to: nil, in: &sectionSnapshot)
      currentSectionSnapshot = sectionSnapshot
      await dataSource.apply(sectionSnapshot, to: 0, animatingDifferences: animatingDifferences)
    }
    applyTask = task
    await withTaskCancellationHandler {
      await task.value
    } onCancel: {
      task.cancel()
    }
  }

  /// Programmatically expands the specified item, making its children visible.
  ///
  /// This method participates in the same task serialization chain as ``setItems(_:animatingDifferences:)``
  /// to prevent interleaved applies.
  ///
  /// - Parameters:
  ///   - item: The item to expand. Must be present in the current outline and have children.
  ///   - animated: Whether to animate the expansion. Defaults to `true`.
  public func expand(_ item: Item, animated: Bool = true) async {
    applyTask?.cancel()
    let previousTask = applyTask
    let task = Task { [weak self] in
      _ = await previousTask?.value
      guard !Task.isCancelled, let self else { return }
      guard var sectionSnapshot = currentSectionSnapshot, sectionSnapshot.contains(item) else { return }
      sectionSnapshot.expand([item])
      currentSectionSnapshot = sectionSnapshot
      await dataSource.apply(sectionSnapshot, to: 0, animatingDifferences: animated)
    }
    applyTask = task
    await withTaskCancellationHandler { await task.value } onCancel: { task.cancel() }
  }

  /// Programmatically collapses the specified item, hiding its children.
  ///
  /// This method participates in the same task serialization chain as ``setItems(_:animatingDifferences:)``
  /// to prevent interleaved applies.
  ///
  /// - Parameters:
  ///   - item: The item to collapse. Must be present in the current outline and have children.
  ///   - animated: Whether to animate the collapse. Defaults to `true`.
  public func collapse(_ item: Item, animated: Bool = true) async {
    applyTask?.cancel()
    let previousTask = applyTask
    let task = Task { [weak self] in
      _ = await previousTask?.value
      guard !Task.isCancelled, let self else { return }
      guard var sectionSnapshot = currentSectionSnapshot, sectionSnapshot.contains(item) else { return }
      sectionSnapshot.collapse([item])
      currentSectionSnapshot = sectionSnapshot
      await dataSource.apply(sectionSnapshot, to: 0, animatingDifferences: animated)
    }
    applyTask = task
    await withTaskCancellationHandler { await task.value } onCancel: { task.cancel() }
  }

  /// Returns whether the specified item is currently expanded.
  ///
  /// - Parameter item: The item to check.
  /// - Returns: `true` if the item is expanded, `false` if collapsed or not found.
  public func isExpanded(_ item: Item) -> Bool {
    currentSectionSnapshot?.isExpanded(item) ?? false
  }

  /// Replaces the outline's tree using the ``OutlineItemBuilder`` result builder DSL.
  ///
  /// ```swift
  /// await list.setItems {
  ///     OutlineItem(item: folder, isExpanded: true) {
  ///         OutlineItem(item: fileA)
  ///         OutlineItem(item: fileB)
  ///     }
  ///     OutlineItem(item: standalone)
  /// }
  /// ```
  public func setItems(
    animatingDifferences: Bool = true,
    @OutlineItemBuilder<Item> content: () -> [OutlineItem<Item>]
  ) async {
    await setItems(content(), animatingDifferences: animatingDifferences)
  }

  /// Returns a copy of the current snapshot.
  public func snapshot() -> DiffableDataSourceSnapshot<Int, Item> {
    dataSource.snapshot()
  }

  /// Returns the item at the given index path, or `nil` if out of bounds.
  public func itemIdentifier(for indexPath: IndexPath) -> Item? {
    bridge.itemIdentifier(for: indexPath)
  }

  /// Returns the index path for the specified item, or `nil` if not found.
  public func indexPath(for item: Item) -> IndexPath? {
    bridge.indexPath(for: item)
  }

  /// Deselects all currently selected items.
  ///
  /// - Parameter animated: Whether the deselection should be animated.
  public func deselectAll(animated: Bool = true) {
    for indexPath in collectionView.indexPathsForSelectedItems ?? [] {
      collectionView.deselectItem(at: indexPath, animated: animated)
    }
  }

  /// Programmatically scrolls to the specified item.
  ///
  /// - Returns: `true` if the item was found in the current snapshot and the scroll was
  ///   initiated, `false` if the item is not present. For hierarchical lists, items must
  ///   be visible (not collapsed under a parent) to be scrolled to.
  @discardableResult
  public func scrollToItem(
    _ item: Item,
    at scrollPosition: UICollectionView.ScrollPosition = .centeredVertically,
    animated: Bool = true
  ) -> Bool {
    bridge.scrollToItem(item, in: collectionView, at: scrollPosition, animated: animated)
  }

  public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    bridge.handleDidSelect(in: collectionView, at: indexPath, onSelect: onSelect)
  }

  public func collectionView(_: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
    bridge.handleDidDeselect(at: indexPath, onDeselect: onDeselect)
  }

  public func collectionView(
    _: UICollectionView,
    contextMenuConfigurationForItemAt indexPath: IndexPath,
    point _: CGPoint
  ) -> UIContextMenuConfiguration? {
    bridge.handleContextMenu(at: indexPath, provider: contextMenuProvider)
  }

  public func scrollViewDidScroll(_ scrollView: UIScrollView) {
    scrollViewDelegate?.scrollViewDidScroll?(scrollView)
  }

  public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
    scrollViewDelegate?.scrollViewWillBeginDragging?(scrollView)
  }

  public func scrollViewWillEndDragging(
    _ scrollView: UIScrollView,
    withVelocity velocity: CGPoint,
    targetContentOffset: UnsafeMutablePointer<CGPoint>
  ) {
    scrollViewDelegate?.scrollViewWillEndDragging?(scrollView, withVelocity: velocity, targetContentOffset: targetContentOffset)
  }

  public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
    scrollViewDelegate?.scrollViewDidEndDragging?(scrollView, willDecelerate: decelerate)
  }

  public func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView) {
    scrollViewDelegate?.scrollViewWillBeginDecelerating?(scrollView)
  }

  public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
    scrollViewDelegate?.scrollViewDidEndDecelerating?(scrollView)
  }

  public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
    scrollViewDelegate?.scrollViewDidEndScrollingAnimation?(scrollView)
  }

  public func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool {
    scrollViewDelegate?.scrollViewShouldScrollToTop?(scrollView) ?? true
  }

  public func scrollViewDidScrollToTop(_ scrollView: UIScrollView) {
    scrollViewDelegate?.scrollViewDidScrollToTop?(scrollView)
  }

  public func scrollViewDidChangeAdjustedContentInset(_ scrollView: UIScrollView) {
    scrollViewDelegate?.scrollViewDidChangeAdjustedContentInset?(scrollView)
  }

  // MARK: Private

  private let dataSource: ListDataSource<Int, Item>
  private let bridge: ListConfigurationBridge<Int, Item>
  private let refreshManager = RefreshControlManager()
  private var applyTask: Task<Void, Never>?
  private var currentSectionSnapshot: DiffableDataSourceSectionSnapshot<Item>?

  private func appendItems(
    _ outlineItems: [OutlineItem<Item>],
    to parent: Item?,
    in sectionSnapshot: inout DiffableDataSourceSectionSnapshot<Item>
  ) {
    let items = outlineItems.map(\.item)
    sectionSnapshot.append(items, to: parent)

    for outlineItem in outlineItems {
      if outlineItem.isExpanded {
        sectionSnapshot.expand([outlineItem.item])
      }
      if !outlineItem.children.isEmpty {
        appendItems(outlineItem.children, to: outlineItem.item, in: &sectionSnapshot)
      }
    }
  }
}
