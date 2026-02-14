import ListKit
import UIKit

/// A type-safe data source for a single `CellViewModel` type.
///
/// `ListDataSource` wraps ``CollectionViewDiffableDataSource`` and handles cell registration
/// automatically. Use it when every cell in your collection view shares the same view model type.
///
/// For lists that mix multiple cell types, use ``MixedListDataSource`` instead.
@MainActor
public final class ListDataSource<SectionID: Hashable & Sendable, Item: CellViewModel> {
    /// A convenience alias for the snapshot type used by this data source.
    public typealias Snapshot = DiffableDataSourceSnapshot<SectionID, Item>

    private let registrar: CellRegistrar<Item>
    private let dataSource: CollectionViewDiffableDataSource<SectionID, Item>

    /// Creates a data source for the given collection view, registering the cell type automatically.
    public init(collectionView: UICollectionView) {
        let registrar = CellRegistrar<Item>()
        self.registrar = registrar
        dataSource = CollectionViewDiffableDataSource(collectionView: collectionView) { cv, indexPath, item in
            registrar.dequeue(from: cv, at: indexPath, item: item)
        }
    }

    // MARK: - Apply

    /// Applies the given snapshot, computing and animating the minimal diff.
    public func apply(_ snapshot: Snapshot, animatingDifferences: Bool = true) async {
        await dataSource.apply(snapshot, animatingDifferences: animatingDifferences)
    }

    /// Replaces the current data without diffing, calling `reloadData()` on the collection view.
    public func applyUsingReloadData(_ snapshot: Snapshot) async {
        await dataSource.applySnapshotUsingReloadData(snapshot)
    }

    /// Applies an array of ``SectionModel`` values, building a snapshot automatically.
    public func apply(_ sections: [SectionModel<SectionID, Item>], animatingDifferences: Bool = true) async {
        var snapshot = Snapshot()
        for section in sections {
            snapshot.appendSections([section.id])
            snapshot.appendItems(section.items, toSection: section.id)
        }
        await dataSource.apply(snapshot, animatingDifferences: animatingDifferences)
    }

    /// Applies sections built with the ``SnapshotBuilder`` result builder DSL.
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

    /// Applies a hierarchical section snapshot to a specific section for outline-style content.
    public func apply(
        _ sectionSnapshot: DiffableDataSourceSectionSnapshot<Item>,
        to section: SectionID,
        animatingDifferences: Bool = true
    ) async {
        await dataSource.apply(sectionSnapshot, to: section, animatingDifferences: animatingDifferences)
    }

    // MARK: - Queries

    /// Returns a copy of the current snapshot.
    public func snapshot() -> Snapshot {
        dataSource.snapshot()
    }

    /// Returns the item at the given index path, or `nil` if out of bounds.
    public func itemIdentifier(for indexPath: IndexPath) -> Item? {
        dataSource.itemIdentifier(for: indexPath)
    }

    /// Returns the index path for the specified item, or `nil` if not found.
    public func indexPath(for item: Item) -> IndexPath? {
        dataSource.indexPath(for: item)
    }

    /// Returns the section identifier at the given section index.
    public func sectionIdentifier(for index: Int) -> SectionID? {
        dataSource.sectionIdentifier(for: index)
    }

    /// Returns the index of the specified section identifier.
    public func index(for sectionIdentifier: SectionID) -> Int? {
        dataSource.index(for: sectionIdentifier)
    }

    // MARK: - Supplementary Views

    /// An optional closure for providing supplementary views (headers, footers).
    public var supplementaryViewProvider: CollectionViewDiffableDataSource<SectionID, Item>.SupplementaryViewProvider? {
        get { dataSource.supplementaryViewProvider }
        set { dataSource.supplementaryViewProvider = newValue }
    }
}
