import UIKit

public protocol CellViewModel: Hashable, Sendable {
    associatedtype Cell: UICollectionViewCell
    @MainActor func configure(_ cell: Cell)
}

@MainActor
final class CellRegistrar<Item: CellViewModel> {
    let registration: UICollectionView.CellRegistration<Item.Cell, Item>

    init() {
        registration = UICollectionView.CellRegistration { cell, _, item in
            item.configure(cell)
        }
    }

    func dequeue(from collectionView: UICollectionView, at indexPath: IndexPath, item: Item) -> UICollectionViewCell {
        collectionView.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: item)
    }
}
