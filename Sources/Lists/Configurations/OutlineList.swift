import ListKit
import UIKit

public struct OutlineItem<Item: CellViewModel>: Sendable {
    public let item: Item
    public let children: [OutlineItem<Item>]
    public let isExpanded: Bool

    public init(item: Item, children: [OutlineItem<Item>] = [], isExpanded: Bool = false) {
        self.item = item
        self.children = children
        self.isExpanded = isExpanded
    }
}

@MainActor
public final class OutlineList<Item: CellViewModel>: NSObject, UICollectionViewDelegate {
    public let collectionView: UICollectionView
    private let dataSource: ListDataSource<Int, Item>

    public var onSelect: (@MainActor (Item) -> Void)?

    public init(appearance: UICollectionLayoutListConfiguration.Appearance = .sidebar) {
        let config = UICollectionLayoutListConfiguration(appearance: appearance)
        let layout = UICollectionViewCompositionalLayout.list(using: config)
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        dataSource = ListDataSource(collectionView: collectionView)
        super.init()
        collectionView.delegate = self
    }

    public func setItems(_ items: [OutlineItem<Item>], animatingDifferences: Bool = true) async {
        var sectionSnapshot = DiffableDataSourceSectionSnapshot<Item>()
        appendItems(items, to: nil, in: &sectionSnapshot)

        // Ensure the section exists in the main snapshot
        let currentSnapshot = dataSource.snapshot()
        if currentSnapshot.numberOfSections == 0 {
            var snapshot = DiffableDataSourceSnapshot<Int, Item>()
            snapshot.appendSections([0])
            await dataSource.applyUsingReloadData(snapshot)
        }

        await dataSource.apply(sectionSnapshot, to: 0, animatingDifferences: animatingDifferences)
    }

    public func snapshot() -> DiffableDataSourceSnapshot<Int, Item> {
        dataSource.snapshot()
    }

    // MARK: - UICollectionViewDelegate

    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        onSelect?(item)
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
