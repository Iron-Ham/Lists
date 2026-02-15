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
  public init(appearance: UICollectionLayoutListConfiguration.Appearance = .plain) {
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

}
