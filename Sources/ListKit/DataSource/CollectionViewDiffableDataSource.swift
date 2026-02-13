import UIKit

@MainActor
public final class CollectionViewDiffableDataSource<
    SectionIdentifierType: Hashable & Sendable,
    ItemIdentifierType: Hashable & Sendable
>: NSObject, UICollectionViewDataSource {
    // MARK: - Typealiases

    public typealias CellProvider = @MainActor (
        UICollectionView, IndexPath, ItemIdentifierType
    ) -> UICollectionViewCell?

    public typealias SupplementaryViewProvider = @MainActor (
        UICollectionView, String, IndexPath
    ) -> UICollectionReusableView?

    // MARK: - Properties

    private weak var collectionView: UICollectionView?
    private let cellProvider: CellProvider
    public var supplementaryViewProvider: SupplementaryViewProvider?
    private var currentSnapshot = DiffableDataSourceSnapshot<SectionIdentifierType, ItemIdentifierType>()
    private var fallbackRegistrations: [String: UICollectionView.SupplementaryRegistration<UICollectionReusableView>] = [:]

    /// Serializes completion-handler `apply()` calls so concurrent calls
    /// don't race on `currentSnapshot` while a batch update is in flight.
    private var applyTask: Task<Void, Never>?

    // MARK: - Initialization

    public init(collectionView: UICollectionView, cellProvider: @escaping CellProvider) {
        self.collectionView = collectionView
        self.cellProvider = cellProvider
        super.init()
        collectionView.dataSource = self
    }

    // MARK: - Apply Methods

    /// Primary apply — async with animated differences
    public func apply(
        _ snapshot: DiffableDataSourceSnapshot<SectionIdentifierType, ItemIdentifierType>,
        animatingDifferences: Bool = true
    ) async {
        guard let collectionView else { return }

        let changeset = SectionedDiff.diff(
            old: currentSnapshot,
            new: snapshot
        )

        currentSnapshot = snapshot

        // No structural changes — skip UI update entirely
        if changeset.isEmpty {
            return
        }

        if !animatingDifferences {
            collectionView.reloadData()
            return
        }

        // Fast path: only reloads/reconfigures, no structural changes.
        // Skip performBatchUpdates entirely — apply directly without the batch overhead.
        if !changeset.hasStructuralChanges {
            if !changeset.sectionReloads.isEmpty {
                collectionView.reloadSections(changeset.sectionReloads)
            }
            if !changeset.itemReloads.isEmpty {
                collectionView.reloadItems(at: changeset.itemReloads)
            }
            if !changeset.itemReconfigures.isEmpty {
                collectionView.reconfigureItems(at: changeset.itemReconfigures)
            }
            return
        }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            collectionView.performBatchUpdates {
                // Deletes (old indices)
                if !changeset.sectionDeletes.isEmpty {
                    collectionView.deleteSections(changeset.sectionDeletes)
                }
                if !changeset.itemDeletes.isEmpty {
                    collectionView.deleteItems(at: changeset.itemDeletes)
                }

                // Inserts (new indices)
                if !changeset.sectionInserts.isEmpty {
                    collectionView.insertSections(changeset.sectionInserts)
                }
                if !changeset.itemInserts.isEmpty {
                    collectionView.insertItems(at: changeset.itemInserts)
                }

                // Moves
                for move in changeset.sectionMoves {
                    collectionView.moveSection(move.from, toSection: move.to)
                }
                for move in changeset.itemMoves {
                    collectionView.moveItem(at: move.from, to: move.to)
                }
            } completion: { _ in
                // Reloads and reconfigures run after the batch completes, using new indices.
                // This matches Apple's NSDiffableDataSourceSnapshot behavior.
                guard collectionView.window != nil else {
                    continuation.resume()
                    return
                }
                if !changeset.sectionReloads.isEmpty {
                    collectionView.reloadSections(changeset.sectionReloads)
                }
                if !changeset.itemReloads.isEmpty {
                    collectionView.reloadItems(at: changeset.itemReloads)
                }
                if !changeset.itemReconfigures.isEmpty {
                    collectionView.reconfigureItems(at: changeset.itemReconfigures)
                }
                continuation.resume()
            }
        }
    }

    /// Convenience — completion handler variant. Applies are serialized to prevent
    /// concurrent calls from racing on `currentSnapshot`.
    public func apply(
        _ snapshot: DiffableDataSourceSnapshot<SectionIdentifierType, ItemIdentifierType>,
        animatingDifferences: Bool = true,
        completion: (() -> Void)? = nil
    ) {
        let previousTask = applyTask
        applyTask = Task { @MainActor in
            // Wait for any in-flight apply to finish before starting ours
            _ = await previousTask?.value
            await apply(snapshot, animatingDifferences: animatingDifferences)
            completion?()
        }
    }

    /// Reload without diffing
    public func applySnapshotUsingReloadData(
        _ snapshot: DiffableDataSourceSnapshot<SectionIdentifierType, ItemIdentifierType>
    ) async {
        currentSnapshot = snapshot
        collectionView?.reloadData()
    }

    /// Apply section snapshot to a specific section
    public func apply(
        _ sectionSnapshot: DiffableDataSourceSectionSnapshot<ItemIdentifierType>,
        to section: SectionIdentifierType,
        animatingDifferences: Bool = true
    ) async {
        // Build a new full snapshot incorporating the section snapshot's visible items
        var newSnapshot = currentSnapshot
        let oldItems = newSnapshot.itemIdentifiers(inSection: section)
        newSnapshot.deleteItems(oldItems)
        let visibleItems = sectionSnapshot.visibleItems
        if !visibleItems.isEmpty {
            newSnapshot.appendItems(visibleItems, toSection: section)
        }
        await apply(newSnapshot, animatingDifferences: animatingDifferences)
    }

    /// Get section snapshot for a specific section
    public func snapshot(
        for section: SectionIdentifierType
    ) -> DiffableDataSourceSectionSnapshot<ItemIdentifierType> {
        var sectionSnapshot = DiffableDataSourceSectionSnapshot<ItemIdentifierType>()
        let items = currentSnapshot.itemIdentifiers(inSection: section)
        sectionSnapshot.append(items)
        return sectionSnapshot
    }

    // MARK: - Query Methods

    public func snapshot() -> DiffableDataSourceSnapshot<SectionIdentifierType, ItemIdentifierType> {
        currentSnapshot
    }

    public func itemIdentifier(for indexPath: IndexPath) -> ItemIdentifierType? {
        guard indexPath.section < currentSnapshot.numberOfSections else { return nil }
        return currentSnapshot.itemIdentifier(inSectionAt: indexPath.section, itemIndex: indexPath.item)
    }

    public func indexPath(for itemIdentifier: ItemIdentifierType) -> IndexPath? {
        guard let section = currentSnapshot.sectionIdentifier(containingItem: itemIdentifier) else {
            return nil
        }
        guard let sectionIndex = currentSnapshot.index(ofSection: section) else { return nil }
        let items = currentSnapshot.itemIdentifiers(inSection: section)
        guard let itemIndex = items.firstIndex(of: itemIdentifier) else { return nil }
        return IndexPath(item: itemIndex, section: sectionIndex)
    }

    public func sectionIdentifier(for index: Int) -> SectionIdentifierType? {
        guard index < currentSnapshot.sectionIdentifiers.count else { return nil }
        return currentSnapshot.sectionIdentifiers[index]
    }

    public func index(for sectionIdentifier: SectionIdentifierType) -> Int? {
        currentSnapshot.index(ofSection: sectionIdentifier)
    }

    // MARK: - UICollectionViewDataSource

    public func numberOfSections(in _: UICollectionView) -> Int {
        currentSnapshot.numberOfSections
    }

    public func collectionView(_: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        currentSnapshot.numberOfItems(inSectionAt: section)
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let itemID = currentSnapshot.itemIdentifier(inSectionAt: indexPath.section, itemIndex: indexPath.item) else {
            return UICollectionViewCell()
        }
        return cellProvider(collectionView, indexPath, itemID) ?? UICollectionViewCell()
    }

    public func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        if let view = supplementaryViewProvider?(collectionView, kind, indexPath) {
            return view
        }
        // UICollectionView requires supplementary views to be dequeued via a registration.
        // Lazily create a fallback registration per element kind that returns an empty view.
        if fallbackRegistrations[kind] == nil {
            fallbackRegistrations[kind] = UICollectionView.SupplementaryRegistration<UICollectionReusableView>(
                elementKind: kind
            ) { _, _, _ in }
        }
        return collectionView.dequeueConfiguredReusableSupplementary(
            using: fallbackRegistrations[kind]!, for: indexPath
        )
    }
}
