// ABOUTME: Shared data source algorithms for content-change detection and section snapshot flattening.
// ABOUTME: Used by ListDataSource and MixedListDataSource.
import ListKit

/// Namespace for shared data source algorithms.
///
/// Groups the content-change detection and section snapshot flattening functions
/// that are shared between ``ListDataSource`` and ``MixedListDataSource``.
enum DataSourceAlgorithms {

  /// Computes items that need reconfiguration by comparing old and new snapshots.
  ///
  /// For items that match by identity (`Hashable`/`Equatable`) in both snapshots, calls
  /// `isContentEqual` to determine whether visible content has changed. Returns items
  /// from the new snapshot whose content differs from their counterparts in the old snapshot.
  ///
  /// - Parameters:
  ///   - old: The previous snapshot before the update.
  ///   - new: The new snapshot being applied.
  ///   - isContentEqual: Closure that returns `true` when two identity-matching items have equal content.
  /// - Returns: Items from `new` whose content differs from their counterpart in `old`.
  static func computeItemsToReconfigure<SectionID: Hashable & Sendable, Item: Hashable & Sendable>(
    old: DiffableDataSourceSnapshot<SectionID, Item>,
    new: DiffableDataSourceSnapshot<SectionID, Item>,
    isContentEqual: (Item, Item) -> Bool
  ) -> [Item] {
    let oldItems = old.itemIdentifiers
    guard !oldItems.isEmpty else { return [] }

    var oldLookup = [Item: Item]()
    oldLookup.reserveCapacity(oldItems.count)
    for item in oldItems {
      oldLookup[item] = item
    }

    var toReconfigure = [Item]()
    for newItem in new.itemIdentifiers {
      guard let oldItem = oldLookup[newItem] else { continue }
      if !isContentEqual(newItem, oldItem) {
        toReconfigure.append(newItem)
      }
    }
    return toReconfigure
  }

  /// Flattens a section snapshot's visible items into a full snapshot, replacing the target section's items.
  ///
  /// Returns a new snapshot with the section's items replaced by the section snapshot's
  /// ``DiffableDataSourceSectionSnapshot/visibleItems``. Hierarchical parent–child structure
  /// is not preserved in the returned snapshot.
  ///
  /// - Parameters:
  ///   - sectionSnapshot: The hierarchical section snapshot to flatten.
  ///   - section: The section whose items should be replaced.
  ///   - snapshot: The current full snapshot.
  /// - Returns: A new snapshot with flattened items, or `nil` if the section does not exist.
  static func flattenSectionSnapshot<SectionID: Hashable & Sendable, Item: Hashable & Sendable>(
    _ sectionSnapshot: DiffableDataSourceSectionSnapshot<Item>,
    intoSection section: SectionID,
    of snapshot: DiffableDataSourceSnapshot<SectionID, Item>
  ) -> DiffableDataSourceSnapshot<SectionID, Item>? {
    var newSnapshot = snapshot
    guard newSnapshot.sectionIdentifiers.contains(section) else {
      assertionFailure("Cannot apply section snapshot to non-existent section \(section)")
      return nil
    }
    let oldItems = newSnapshot.itemIdentifiers(inSection: section)
    newSnapshot.deleteItems(oldItems)
    let visibleItems = sectionSnapshot.visibleItems
    if !visibleItems.isEmpty {
      newSnapshot.appendItems(visibleItems, toSection: section)
    }
    return newSnapshot
  }
}
