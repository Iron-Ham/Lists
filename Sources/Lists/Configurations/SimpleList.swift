import ListKit
import UIKit

@MainActor
public final class SimpleList<Item: CellViewModel>: NSObject, UICollectionViewDelegate {
    public let collectionView: UICollectionView
    private let dataSource: ListDataSource<Int, Item>
    private let bridge: SwipeActionBridge<Int, Item>
    private var applyTask: Task<Void, Never>?

    public var onSelect: (@MainActor (Item) -> Void)?

    /// Closure that returns trailing swipe actions for a given item.
    public var trailingSwipeActionsProvider: (@MainActor (Item) -> UISwipeActionsConfiguration?)?
    /// Closure that returns leading swipe actions for a given item.
    public var leadingSwipeActionsProvider: (@MainActor (Item) -> UISwipeActionsConfiguration?)?
    /// Closure that returns a context menu configuration for a given item.
    public var contextMenuProvider: (@MainActor (Item) -> UIContextMenuConfiguration?)?

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

    public func setItems(_ items: [Item], animatingDifferences: Bool = true) async {
        let previousTask = applyTask
        let task = Task { @MainActor in
            _ = await previousTask?.value
            guard !Task.isCancelled else { return }
            var snapshot = DiffableDataSourceSnapshot<Int, Item>()
            snapshot.appendSections([0])
            snapshot.appendItems(items, toSection: 0)
            await self.dataSource.apply(snapshot, animatingDifferences: animatingDifferences)
        }
        applyTask = task
        await task.value
    }

    public func setItems(animatingDifferences: Bool = true, @ItemsBuilder<Item> content: () -> [Item]) async {
        await setItems(content(), animatingDifferences: animatingDifferences)
    }

    public func snapshot() -> DiffableDataSourceSnapshot<Int, Item> {
        dataSource.snapshot()
    }

    // MARK: - UICollectionViewDelegate

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
}
