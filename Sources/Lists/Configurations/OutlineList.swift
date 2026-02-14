import ListKit
import UIKit

public struct OutlineItem<Item: Hashable & Sendable>: Sendable, Equatable {
    public let item: Item
    public let children: [OutlineItem<Item>]
    public let isExpanded: Bool

    public init(item: Item, children: [OutlineItem<Item>] = [], isExpanded: Bool = false) {
        self.item = item
        self.children = children
        self.isExpanded = isExpanded
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

@MainActor
public final class OutlineList<Item: CellViewModel>: NSObject, UICollectionViewDelegate {
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

    public func setItems(_ items: [OutlineItem<Item>], animatingDifferences: Bool = true) async {
        let previousTask = applyTask
        let task = Task { @MainActor in
            _ = await previousTask?.value
            guard !Task.isCancelled else { return }
            var sectionSnapshot = DiffableDataSourceSectionSnapshot<Item>()
            self.appendItems(items, to: nil, in: &sectionSnapshot)

            // Ensure the section exists in the main snapshot
            let currentSnapshot = self.dataSource.snapshot()
            if currentSnapshot.numberOfSections == 0 {
                var snapshot = DiffableDataSourceSnapshot<Int, Item>()
                snapshot.appendSections([0])
                await self.dataSource.applyUsingReloadData(snapshot)
            }

            await self.dataSource.apply(sectionSnapshot, to: 0, animatingDifferences: animatingDifferences)
        }
        applyTask = task
        await task.value
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

    // MARK: - Private

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
