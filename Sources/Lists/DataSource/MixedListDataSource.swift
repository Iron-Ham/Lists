import ListKit
import UIKit

/// A data source that supports multiple `CellViewModel` types in the same collection view.
///
/// `MixedListDataSource` wraps each cell view model in ``AnyItem`` for type erasure,
/// allowing heterogeneous cell types within a single section. Cell classes are registered
/// lazily on first use via ``DynamicCellRegistrar``.
///
/// For lists with a single cell type, prefer ``ListDataSource`` which avoids the type-erasure overhead.
@MainActor
public final class MixedListDataSource<SectionID: Hashable & Sendable> {
    /// A convenience alias for the snapshot type used by this data source.
    public typealias Snapshot = DiffableDataSourceSnapshot<SectionID, AnyItem>

    private let registrar: DynamicCellRegistrar
    private let dataSource: CollectionViewDiffableDataSource<SectionID, AnyItem>

    /// Creates a mixed data source for the given collection view.
    public init(collectionView: UICollectionView) {
        let registrar = DynamicCellRegistrar()
        self.registrar = registrar
        dataSource = CollectionViewDiffableDataSource(collectionView: collectionView) { cv, indexPath, item in
            item._dequeue(cv, indexPath, registrar)
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

    /// Applies sections built with the ``MixedSnapshotBuilder`` result builder DSL.
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

    /// Applies a hierarchical section snapshot to a specific section for outline-style content.
    public func apply(
        _ sectionSnapshot: DiffableDataSourceSectionSnapshot<AnyItem>,
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

    /// Returns the type-erased item at the given index path.
    public func itemIdentifier(for indexPath: IndexPath) -> AnyItem? {
        dataSource.itemIdentifier(for: indexPath)
    }

    /// Returns the index path for the specified item, or `nil` if not found.
    public func indexPath(for item: AnyItem) -> IndexPath? {
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
    public var supplementaryViewProvider: CollectionViewDiffableDataSource<SectionID, AnyItem>.SupplementaryViewProvider? {
        get { dataSource.supplementaryViewProvider }
        set { dataSource.supplementaryViewProvider = newValue }
    }
}
