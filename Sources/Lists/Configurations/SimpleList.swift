import ListKit
import UIKit

@MainActor
public final class SimpleList<Item: CellViewModel>: NSObject, UICollectionViewDelegate {
    public let collectionView: UICollectionView
    private let dataSource: ListDataSource<Int, Item>

    public var onSelect: (@MainActor (Item) -> Void)?

    public init(appearance: UICollectionLayoutListConfiguration.Appearance = .plain) {
        let config = UICollectionLayoutListConfiguration(appearance: appearance)
        let layout = UICollectionViewCompositionalLayout.list(using: config)
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        dataSource = ListDataSource(collectionView: collectionView)
        super.init()
        collectionView.delegate = self
    }

    public func setItems(_ items: [Item], animatingDifferences: Bool = true) async {
        var snapshot = DiffableDataSourceSnapshot<Int, Item>()
        snapshot.appendSections([0])
        snapshot.appendItems(items, toSection: 0)
        await dataSource.apply(snapshot, animatingDifferences: animatingDifferences)
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
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        onSelect?(item)
    }
}
