import ListKit
import UIKit

@MainActor
public final class MixedListDataSource<SectionID: Hashable & Sendable> {
    public typealias Snapshot = DiffableDataSourceSnapshot<SectionID, AnyItem>

    private let registrar: DynamicCellRegistrar
    private let dataSource: CollectionViewDiffableDataSource<SectionID, AnyItem>

    public init(collectionView: UICollectionView) {
        let registrar = DynamicCellRegistrar()
        self.registrar = registrar
        dataSource = CollectionViewDiffableDataSource(collectionView: collectionView) { cv, indexPath, item in
            item._dequeue(cv, indexPath, registrar)
        }
    }

    // MARK: - Apply

    public func apply(_ snapshot: Snapshot, animatingDifferences: Bool = true) async {
        await dataSource.apply(snapshot, animatingDifferences: animatingDifferences)
    }

    public func applyUsingReloadData(_ snapshot: Snapshot) async {
        await dataSource.applySnapshotUsingReloadData(snapshot)
    }

    public func apply(
        animatingDifferences: Bool = true,
        @MixedSnapshotBuilder<SectionID> content: () -> [MixedSection<SectionID>]
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
        _ sectionSnapshot: DiffableDataSourceSectionSnapshot<AnyItem>,
        to section: SectionID,
        animatingDifferences: Bool = true
    ) async {
        await dataSource.apply(sectionSnapshot, to: section, animatingDifferences: animatingDifferences)
    }

    // MARK: - Queries

    public func snapshot() -> Snapshot {
        dataSource.snapshot()
    }

    public func itemIdentifier(for indexPath: IndexPath) -> AnyItem? {
        dataSource.itemIdentifier(for: indexPath)
    }

    public func indexPath(for item: AnyItem) -> IndexPath? {
        dataSource.indexPath(for: item)
    }

    public func sectionIdentifier(for index: Int) -> SectionID? {
        dataSource.sectionIdentifier(for: index)
    }

    public func index(for sectionIdentifier: SectionID) -> Int? {
        dataSource.index(for: sectionIdentifier)
    }

    // MARK: - Supplementary Views

    public var supplementaryViewProvider: CollectionViewDiffableDataSource<SectionID, AnyItem>.SupplementaryViewProvider? {
        get { dataSource.supplementaryViewProvider }
        set { dataSource.supplementaryViewProvider = newValue }
    }
}
