// ABOUTME: Drop-in replacement for UICollectionViewDiffableDataSource.
// ABOUTME: Serializes concurrent applies via Task chaining and uses ListKit's own snapshots.

import UIKit

/// A data source that manages a `UICollectionView` using snapshots and animated batch updates.
///
/// This is a drop-in replacement for `UICollectionViewDiffableDataSource` with two key
/// differences: it uses ListKit's ``DiffableDataSourceSnapshot`` (no Foundation overhead)
/// and serializes concurrent `apply` calls via a `Task` chain rather than a dispatch queue.
@MainActor
public final class CollectionViewDiffableDataSource<
  SectionIdentifierType: Hashable & Sendable,
  ItemIdentifierType: Hashable & Sendable
>: NSObject, UICollectionViewDataSource {

  // MARK: Lifecycle

  /// Creates a data source that provides cells via the given closure.
  ///
  /// The data source automatically registers itself as the collection view's `dataSource`.
  public init(collectionView: UICollectionView, cellProvider: @escaping CellProvider) {
    self.collectionView = collectionView
    self.cellProvider = cellProvider
    super.init()
    collectionView.dataSource = self
  }

  // MARK: Public

  /// A closure that dequeues and configures a cell for a given item.
  public typealias CellProvider = @MainActor (
    UICollectionView,
    IndexPath,
    ItemIdentifierType
  ) -> UICollectionViewCell?

  /// A closure that dequeues and configures a supplementary view (header, footer, etc.).
  public typealias SupplementaryViewProvider = @MainActor (
    UICollectionView,
    String,
    IndexPath
  ) -> UICollectionReusableView?

  /// An optional closure for providing supplementary views (headers, footers).
  public var supplementaryViewProvider: SupplementaryViewProvider?

  /// Optional closure to determine whether a specific item can be reordered.
  /// Return `true` to allow the item at the given index path to be moved.
  public var canMoveItemHandler: (@MainActor (IndexPath) -> Bool)?

  /// Optional closure called after the user finishes reordering an item via drag-and-drop.
  /// The data source updates its internal snapshot automatically; use this closure to
  /// persist the new order in your model layer.
  public var didMoveItemHandler: (@MainActor (IndexPath, IndexPath) -> Void)?

  /// Primary apply — async with animated differences.
  /// Serialized: concurrent calls are queued and executed in order.
  /// Supports cooperative cancellation — cancelled tasks skip the apply.
  public func apply(
    _ snapshot: DiffableDataSourceSnapshot<SectionIdentifierType, ItemIdentifierType>,
    animatingDifferences: Bool = true
  ) async {
    let previousTask = applyTask
    let task = Task { @MainActor in
      _ = await previousTask?.value
      guard !Task.isCancelled else { return }
      await self.performApply(snapshot, animatingDifferences: animatingDifferences)
    }
    applyTask = task
    await task.value
  }

  /// Convenience — completion handler variant.
  /// Serialized: concurrent calls are queued and executed in order.
  public func apply(
    _ snapshot: DiffableDataSourceSnapshot<SectionIdentifierType, ItemIdentifierType>,
    animatingDifferences: Bool = true,
    completion: (() -> Void)? = nil
  ) {
    let previousTask = applyTask
    applyTask = Task { @MainActor in
      _ = await previousTask?.value
      await self.performApply(snapshot, animatingDifferences: animatingDifferences)
      completion?()
    }
  }

  /// Reload without diffing.
  /// Serialized with `apply()` to prevent snapshot/UI mismatch when both are in flight.
  public func applySnapshotUsingReloadData(
    _ snapshot: DiffableDataSourceSnapshot<SectionIdentifierType, ItemIdentifierType>
  ) async {
    let previousTask = applyTask
    let task = Task { @MainActor in
      _ = await previousTask?.value
      guard !Task.isCancelled else { return }
      self.currentSnapshot = snapshot
      self.collectionView?.reloadData()
    }
    applyTask = task
    await task.value
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

  /// Returns a copy of the data source's current snapshot.
  public func snapshot() -> DiffableDataSourceSnapshot<SectionIdentifierType, ItemIdentifierType> {
    currentSnapshot
  }

  /// Returns the item at the given index path, or `nil` if out of bounds.
  public func itemIdentifier(for indexPath: IndexPath) -> ItemIdentifierType? {
    guard indexPath.section < currentSnapshot.numberOfSections else { return nil }
    return currentSnapshot.itemIdentifier(inSectionAt: indexPath.section, itemIndex: indexPath.item)
  }

  /// Returns the index path for the specified item, or `nil` if not found.
  public func indexPath(for itemIdentifier: ItemIdentifierType) -> IndexPath? {
    guard let section = currentSnapshot.sectionIdentifier(containingItem: itemIdentifier) else {
      return nil
    }
    guard let sectionIndex = currentSnapshot.index(ofSection: section) else { return nil }
    let items = currentSnapshot.itemIdentifiers(inSection: section)
    guard let itemIndex = items.firstIndex(of: itemIdentifier) else { return nil }
    return IndexPath(item: itemIndex, section: sectionIndex)
  }

  /// Returns the section identifier at the given section index, or `nil` if out of bounds.
  public func sectionIdentifier(for index: Int) -> SectionIdentifierType? {
    guard index < currentSnapshot.sectionIdentifiers.count else { return nil }
    return currentSnapshot.sectionIdentifiers[index]
  }

  /// Returns the index of the specified section identifier, or `nil` if not found.
  public func index(for sectionIdentifier: SectionIdentifierType) -> Int? {
    currentSnapshot.index(ofSection: sectionIdentifier)
  }

  public func numberOfSections(in _: UICollectionView) -> Int {
    currentSnapshot.numberOfSections
  }

  public func collectionView(_: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    currentSnapshot.numberOfItems(inSectionAt: section)
  }

  public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    guard let itemID = currentSnapshot.itemIdentifier(inSectionAt: indexPath.section, itemIndex: indexPath.item) else {
      assertionFailure("Snapshot/UICollectionView mismatch: no item at \(indexPath)")
      return UICollectionViewCell()
    }
    guard let cell = cellProvider(collectionView, indexPath, itemID) else {
      assertionFailure("cellProvider returned nil for item at \(indexPath)")
      return UICollectionViewCell()
    }
    return cell
  }

  public func collectionView(_: UICollectionView, canMoveItemAt indexPath: IndexPath) -> Bool {
    canMoveItemHandler?(indexPath) ?? false
  }

  public func collectionView(
    _: UICollectionView,
    moveItemAt sourceIndexPath: IndexPath,
    to destinationIndexPath: IndexPath
  ) {
    guard let item = itemIdentifier(for: sourceIndexPath) else {
      assertionFailure("Move failed: no item at source \(sourceIndexPath)")
      return
    }

    // Validate destination before mutating the snapshot to prevent data loss.
    guard destinationIndexPath.section < currentSnapshot.sectionIdentifiers.count else {
      assertionFailure("Move failed: destination section \(destinationIndexPath.section) out of bounds")
      return
    }

    // Remove the item from its current position in the snapshot
    currentSnapshot.deleteItems([item])

    // Insert at the destination
    let destSectionID = currentSnapshot.sectionIdentifiers[destinationIndexPath.section]
    let destItems = currentSnapshot.itemIdentifiers(inSection: destSectionID)

    if destinationIndexPath.item < destItems.count {
      currentSnapshot.insertItems([item], beforeItem: destItems[destinationIndexPath.item])
    } else {
      currentSnapshot.appendItems([item], toSection: destSectionID)
    }

    didMoveItemHandler?(sourceIndexPath, destinationIndexPath)
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
    assert(
      fallbackRegistrations.count < 10,
      "Excessive supplementary element kinds (\(fallbackRegistrations.count)). Verify element kinds are not dynamically generated."
    )
    let registration: UICollectionView.SupplementaryRegistration<UICollectionReusableView>
    if let existing = fallbackRegistrations[kind] {
      registration = existing
    } else {
      let newReg = UICollectionView.SupplementaryRegistration<UICollectionReusableView>(
        elementKind: kind
      ) { _, _, _ in }
      fallbackRegistrations[kind] = newReg
      registration = newReg
    }
    return collectionView.dequeueConfiguredReusableSupplementary(
      using: registration,
      for: indexPath
    )
  }

  // MARK: Private

  /// Item count threshold above which diff computation is offloaded to a
  /// background thread via `Task.detached`. Below this threshold, diffing
  /// runs inline to avoid thread-hop overhead.
  private static var backgroundDiffThreshold: Int {
    1_000
  }

  private weak var collectionView: UICollectionView?
  private let cellProvider: CellProvider
  private var currentSnapshot = DiffableDataSourceSnapshot<SectionIdentifierType, ItemIdentifierType>()
  private var fallbackRegistrations = [String: UICollectionView.SupplementaryRegistration<UICollectionReusableView>]()

  /// Serializes completion-handler `apply()` calls so concurrent calls
  /// don't race on `currentSnapshot` while a batch update is in flight.
  private var applyTask: Task<Void, Never>?

  /// Core apply logic — called only from serialized public methods.
  ///
  /// `currentSnapshot` must remain at the old value until UIKit captures pre-update
  /// counts inside `performBatchUpdates`. UIKit validates:
  ///   `pre_count + inserts - deletes == post_count`
  /// so we advance `currentSnapshot` inside the batch block (after mutations) for the
  /// structural path, and immediately before the UI call for all other paths.
  private func performApply(
    _ snapshot: DiffableDataSourceSnapshot<SectionIdentifierType, ItemIdentifierType>,
    animatingDifferences: Bool
  ) async {
    let oldSnapshot = currentSnapshot

    guard let collectionView else {
      // No UI to update — still advance the snapshot so future diffs are correct.
      currentSnapshot = snapshot
      return
    }

    let itemCount = max(oldSnapshot.numberOfItems, snapshot.numberOfItems)
    let changeset: StagedChangeset<SectionIdentifierType, ItemIdentifierType>

    if itemCount >= Self.backgroundDiffThreshold {
      let old = oldSnapshot
      let new = snapshot
      changeset = await Task.detached(priority: .userInitiated) {
        SectionedDiff.diff(old: old, new: new)
      }.value
    } else {
      changeset = SectionedDiff.diff(old: oldSnapshot, new: snapshot)
    }

    guard !Task.isCancelled else {
      return
    }

    // No changes — still advance the snapshot (may differ in metadata).
    if changeset.isEmpty {
      currentSnapshot = snapshot
      return
    }

    if !animatingDifferences {
      currentSnapshot = snapshot
      collectionView.reloadData()
      return
    }

    // Fast path: only reloads/reconfigures, no structural changes.
    // Skip performBatchUpdates entirely — apply directly without the batch overhead.
    if !changeset.hasStructuralChanges {
      currentSnapshot = snapshot
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

        // Advance the snapshot INSIDE the batch block so UIKit sees old counts
        // before the block and new counts after. Placing this before the block
        // causes UIKit to read the new count for both pre and post, breaking its
        // `pre_count + inserts - deletes == post_count` invariant.
        self.currentSnapshot = snapshot
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

}
