import ListKit
import UIKit

// MARK: - OutlineItem

/// A node in a tree structure used by ``OutlineList`` to represent hierarchical data.
///
/// Each `OutlineItem` wraps a value and optionally has children. The `isExpanded` flag
/// controls whether children are visible when the outline is rendered.
public struct OutlineItem<Item: Hashable & Sendable>: Sendable, Equatable {

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

  /// Creates an outline list with the specified list appearance.
  public init(appearance: UICollectionLayoutListConfiguration.Appearance = .sidebar) {
    let bridge = SwipeActionBridge<Int, Item>()
    self.bridge = bridge

    var config = UICollectionLayoutListConfiguration(appearance: appearance)
    bridge.configureSwipeActions(on: &config)
    let layout = UICollectionViewCompositionalLayout.list(using: config)

    collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
    dataSource = ListDataSource(collectionView: collectionView)
    super.init()
    collectionView.delegate = self

    bridge.dataSource = dataSource
    bridge.trailingProvider = { [weak self] item in self?.trailingSwipeActionsProvider?(item) }
    bridge.leadingProvider = { [weak self] item in self?.leadingSwipeActionsProvider?(item) }
  }

  // MARK: Public

  /// The underlying collection view. Add this to your view hierarchy.
  public let collectionView: UICollectionView
  /// Called when the user taps an item.
  public var onSelect: (@MainActor (Item) -> Void)?

  /// Closure that returns trailing swipe actions for a given item.
  public var trailingSwipeActionsProvider: (@MainActor (Item) -> UISwipeActionsConfiguration?)?
  /// Closure that returns leading swipe actions for a given item.
  public var leadingSwipeActionsProvider: (@MainActor (Item) -> UISwipeActionsConfiguration?)?
  /// Closure that returns a context menu configuration for a given item.
  public var contextMenuProvider: (@MainActor (Item) -> UIContextMenuConfiguration?)?

  /// Replaces the outline's tree, computing and animating the diff.
  ///
  /// Cancels any previously queued apply so only the most recent snapshot is applied,
  /// and supports cooperative cancellation from the calling task.
  public func setItems(_ items: [OutlineItem<Item>], animatingDifferences: Bool = true) async {
    applyTask?.cancel()
    let previousTask = applyTask
    let task = Task { [weak self] in
      _ = await previousTask?.value
      guard !Task.isCancelled, let self else { return }
      var sectionSnapshot = DiffableDataSourceSectionSnapshot<Item>()
      appendItems(items, to: nil, in: &sectionSnapshot)

      // Build the full snapshot in one pass: ensure section exists, then replace items
      // with the visible items from the section snapshot. This avoids two sequential applies
      // and ensures everything goes through the serialized apply path.
      var mainSnapshot = dataSource.snapshot()
      if mainSnapshot.numberOfSections == 0 {
        mainSnapshot.appendSections([0])
      }
      let oldItems = mainSnapshot.itemIdentifiers(inSection: 0)
      if !oldItems.isEmpty {
        mainSnapshot.deleteItems(oldItems)
      }
      let visibleItems = sectionSnapshot.visibleItems
      if !visibleItems.isEmpty {
        mainSnapshot.appendItems(visibleItems, toSection: 0)
      }
      await dataSource.apply(mainSnapshot, animatingDifferences: animatingDifferences)
    }
    applyTask = task
    await withTaskCancellationHandler {
      await task.value
    } onCancel: {
      task.cancel()
    }
  }

  /// Returns a copy of the current snapshot.
  public func snapshot() -> DiffableDataSourceSnapshot<Int, Item> {
    dataSource.snapshot()
  }

  public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    collectionView.deselectItem(at: indexPath, animated: true)
    guard let item = dataSource.itemIdentifier(for: indexPath) else {
      assertionFailure("Item not found for indexPath \(indexPath)")
      return
    }
    onSelect?(item)
  }

  public func collectionView(
    _: UICollectionView,
    contextMenuConfigurationForItemAt indexPath: IndexPath,
    point _: CGPoint
  ) -> UIContextMenuConfiguration? {
    guard let item = dataSource.itemIdentifier(for: indexPath) else { return nil }
    return contextMenuProvider?(item)
  }

  // MARK: Private

  private let dataSource: ListDataSource<Int, Item>
  private let bridge: SwipeActionBridge<Int, Item>
  private var applyTask: Task<Void, Never>?

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
