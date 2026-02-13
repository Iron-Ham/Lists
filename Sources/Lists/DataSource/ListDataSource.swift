import ListKit
import UIKit

@MainActor
public final class ListDataSource<SectionID: Hashable & Sendable, Item: CellViewModel> {
    public typealias Snapshot = DiffableDataSourceSnapshot<SectionID, Item>

    private let registrar: CellRegistrar<Item>
    private let dataSource: CollectionViewDiffableDataSource<SectionID, Item>

    public init(collectionView: UICollectionView) {
        let registrar = CellRegistrar<Item>()
        self.registrar = registrar
        dataSource = CollectionViewDiffableDataSource(collectionView: collectionView) { cv, indexPath, item in
            registrar.dequeue(from: cv, at: indexPath, item: item)
        }
    }

    // MARK: - Apply

    public func apply(_ snapshot: Snapshot, animatingDifferences: Bool = true) async {
        await dataSource.apply(snapshot, animatingDifferences: animatingDifferences)
    }

    public func applyUsingReloadData(_ snapshot: Snapshot) async {
        await dataSource.applySnapshotUsingReloadData(snapshot)
    }

    public func apply(_ sections: [SectionModel<SectionID, Item>], animatingDifferences: Bool = true) async {
        var snapshot = Snapshot()
        for section in sections {
            snapshot.appendSections([section.id])
            snapshot.appendItems(section.items, toSection: section.id)
        }
        await dataSource.apply(snapshot, animatingDifferences: animatingDifferences)
    }

    public func apply(
        animatingDifferences: Bool = true,
        @SnapshotBuilder<SectionID, Item> content: () -> [SnapshotSection<SectionID, Item>]
    ) async {
        let sections = content()
        var snapshot = Snapshot()
        for section in sections {
            snapshot.appendSections([section.id])
            snapshot.appendItems(section.items, toSection: section.id)
        }
        await dataSource.apply(snapshot, animatingDifferences: animatingDifferences)
    }

    // MARK: - Section Snapshot

    public func apply(
        _ sectionSnapshot: DiffableDataSourceSectionSnapshot<Item>,
        to section: SectionID,
        animatingDifferences: Bool = true
    ) async {
        await dataSource.apply(sectionSnapshot, to: section, animatingDifferences: animatingDifferences)
    }

    // MARK: - Queries

    public func snapshot() -> Snapshot {
        dataSource.snapshot()
    }

    public func itemIdentifier(for indexPath: IndexPath) -> Item? {
        dataSource.itemIdentifier(for: indexPath)
    }

    public func indexPath(for item: Item) -> IndexPath? {
        dataSource.indexPath(for: item)
    }

    public func sectionIdentifier(for index: Int) -> SectionID? {
        dataSource.sectionIdentifier(for: index)
    }

    public func index(for sectionIdentifier: SectionID) -> Int? {
        dataSource.index(for: sectionIdentifier)
    }

    // MARK: - Supplementary Views

    public var supplementaryViewProvider: CollectionViewDiffableDataSource<SectionID, Item>.SupplementaryViewProvider? {
        get { dataSource.supplementaryViewProvider }
        set { dataSource.supplementaryViewProvider = newValue }
    }
}
