// ABOUTME: Type-safe data source for a single CellViewModel type.
// ABOUTME: Wraps CollectionViewDiffableDataSource with automatic cell registration.
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

  // MARK: Lifecycle

  /// Creates a data source for the given collection view, registering the cell type automatically.
  public init(collectionView: UICollectionView) {
    let registrar = CellRegistrar<Item>()
    self.registrar = registrar
    dataSource = CollectionViewDiffableDataSource(collectionView: collectionView) { cv, indexPath, item in
      registrar.dequeue(from: cv, at: indexPath, item: item)
    }
  }

  // MARK: Public

  /// A convenience alias for the snapshot type used by this data source.
  public typealias Snapshot = DiffableDataSourceSnapshot<SectionID, Item>

  /// An optional closure for providing supplementary views (headers, footers).
  public var supplementaryViewProvider: CollectionViewDiffableDataSource<SectionID, Item>.SupplementaryViewProvider? {
    get { dataSource.supplementaryViewProvider }
    set { dataSource.supplementaryViewProvider = newValue }
  }

  /// Optional closure to determine whether a specific item can be reordered.
  public var canMoveItemHandler: (@MainActor (IndexPath) -> Bool)? {
    get { dataSource.canMoveItemHandler }
    set { dataSource.canMoveItemHandler = newValue }
  }

  /// Optional closure called after the user finishes reordering an item.
  public var didMoveItemHandler: (@MainActor (IndexPath, IndexPath) -> Void)? {
    get { dataSource.didMoveItemHandler }
    set { dataSource.didMoveItemHandler = newValue }
  }

  /// Applies the given snapshot, computing and animating the minimal diff.
  ///
  /// When `Item` conforms to ``ContentEquatable``, items whose identity matches
  /// but whose content has changed are automatically marked for reconfiguration.
  public func apply(_ snapshot: Snapshot, animatingDifferences: Bool = true) async {
    var snapshot = snapshot
    autoReconfigure(old: dataSource.snapshot(), new: &snapshot)
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
    await apply(snapshot, animatingDifferences: animatingDifferences)
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
    await apply(snapshot, animatingDifferences: animatingDifferences)
  }

  /// Applies a hierarchical section snapshot to a specific section for outline-style content.
  public func apply(
    _ sectionSnapshot: DiffableDataSourceSectionSnapshot<Item>,
    to section: SectionID,
    animatingDifferences: Bool = true
  ) async {
    await dataSource.apply(sectionSnapshot, to: section, animatingDifferences: animatingDifferences)
  }

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

  // MARK: Private

  private let registrar: CellRegistrar<Item>
  private let dataSource: CollectionViewDiffableDataSource<SectionID, Item>

  /// Detects content changes for ``ContentEquatable`` items and marks them for reconfiguration.
  ///
  /// For items that match by identity (Hashable/Equatable) in both old and new snapshots,
  /// checks `isContentEqual(to:)`. Items whose content differs are added to the new snapshot's
  /// `reconfiguredItemIdentifiers`, triggering an in-place cell update on the next apply.
  private func autoReconfigure(old: Snapshot, new: inout Snapshot) {
    guard Item.self is any ContentEquatable.Type else { return }

    let oldItems = old.itemIdentifiers
    guard !oldItems.isEmpty else { return }

    var oldLookup = [Item: Item]()
    oldLookup.reserveCapacity(oldItems.count)
    for item in oldItems {
      oldLookup[item] = item
    }

    var toReconfigure = [Item]()
    for newItem in new.itemIdentifiers {
      guard let oldItem = oldLookup[newItem] else { continue }
      guard let newCE = newItem as? any ContentEquatable else {
        assertionFailure("Item passed type-level ContentEquatable check but failed instance cast")
        continue
      }
      if !newCE.isContentEqualTypeErased(to: oldItem) {
        toReconfigure.append(newItem)
      }
    }

    if !toReconfigure.isEmpty {
      new.reconfigureItems(toReconfigure)
    }
  }

}
