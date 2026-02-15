import ListKit
import UIKit

/// A single-section flat list backed by a `UICollectionView`.
///
/// `SimpleList` is the easiest way to display a homogeneous list. It manages layout,
/// data source, and delegation internally — you just provide items and handlers.
///
/// ```swift
/// let list = SimpleList<ContactItem>()
/// list.onSelect = { item in print(item) }
/// await list.setItems(contacts)
/// ```
@MainActor
public final class SimpleList<Item: CellViewModel>: NSObject, UICollectionViewDelegate {

  // MARK: Lifecycle

  /// Creates a simple list with the specified list appearance.
  public init(
    appearance: UICollectionLayoutListConfiguration.Appearance = .plain,
    showsSeparators: Bool = true
  ) {
    let bridge = SwipeActionBridge<Int, Item>()
    self.bridge = bridge

    var config = UICollectionLayoutListConfiguration(appearance: appearance)
    config.showsSeparators = showsSeparators
    bridge.configureSwipeActions(on: &config)
    let layout = UICollectionViewCompositionalLayout.list(using: config)

    collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
    dataSource = ListDataSource(collectionView: collectionView)
    super.init()
    collectionView.delegate = self

    bridge.dataSource = dataSource
    bridge.trailingProvider = { [weak self] item in
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
    bridge.leadingProvider = { [weak self] item in self?.leadingSwipeActionsProvider?(item) }
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
  public var onDelete: (@MainActor (Item) -> Void)?

  /// Closure that returns trailing swipe actions for a given item.
  public var trailingSwipeActionsProvider: (@MainActor (Item) -> UISwipeActionsConfiguration?)?
  /// Closure that returns leading swipe actions for a given item.
  public var leadingSwipeActionsProvider: (@MainActor (Item) -> UISwipeActionsConfiguration?)?
  /// Closure that returns a context menu configuration for a given item.
  public var contextMenuProvider: (@MainActor (Item) -> UIContextMenuConfiguration?)?

  /// Called when the user reorders an item via drag-and-drop.
  /// The list updates its internal snapshot automatically; use this to persist the new order.
  /// Setting this enables the reorder interaction on the collection view.
  public var onMove: (@MainActor (_ source: IndexPath, _ destination: IndexPath) -> Void)? {
    didSet { configureReorderIfNeeded() }
  }

  /// Replaces the list's items, computing and animating the diff.
  ///
  /// Cancels any previously queued apply so only the most recent snapshot is applied,
  /// and supports cooperative cancellation from the calling task.
  public func setItems(_ items: [Item], animatingDifferences: Bool = true) async {
    applyTask?.cancel()
    let previousTask = applyTask
    let task = Task { [weak self] in
      _ = await previousTask?.value
      guard !Task.isCancelled, let self else { return }
      var snapshot = DiffableDataSourceSnapshot<Int, Item>()
      snapshot.appendSections([0])
      snapshot.appendItems(items, toSection: 0)
      await dataSource.apply(snapshot, animatingDifferences: animatingDifferences)
    }
    applyTask = task
    await withTaskCancellationHandler {
      await task.value
    } onCancel: {
      task.cancel()
    }
  }

  /// Replaces the list's items using the ``ItemsBuilder`` result builder DSL.
  public func setItems(animatingDifferences: Bool = true, @ItemsBuilder<Item> content: () -> [Item]) async {
    await setItems(content(), animatingDifferences: animatingDifferences)
  }

  /// Returns a copy of the current snapshot.
  public func snapshot() -> DiffableDataSourceSnapshot<Int, Item> {
    dataSource.snapshot()
  }

  public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    if !collectionView.allowsMultipleSelection {
      collectionView.deselectItem(at: indexPath, animated: true)
    }
    guard let item = dataSource.itemIdentifier(for: indexPath) else {
      assertionFailure("Item not found for indexPath \(indexPath)")
      return
    }
    onSelect?(item)
  }

  public func collectionView(_: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
    guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
    onDeselect?(item)
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

  private func configureReorderIfNeeded() {
    if onMove != nil {
      collectionView.dragInteractionEnabled = true
      dataSource.canMoveItemHandler = { _ in true }
      dataSource.didMoveItemHandler = { [weak self] source, dest in
        self?.onMove?(source, dest)
      }
    } else {
      collectionView.dragInteractionEnabled = false
      dataSource.canMoveItemHandler = nil
      dataSource.didMoveItemHandler = nil
    }
  }

}
