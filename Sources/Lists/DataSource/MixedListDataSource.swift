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

  // MARK: Lifecycle

  /// Creates a mixed data source for the given collection view.
  public init(collectionView: UICollectionView) {
    let registrar = DynamicCellRegistrar()
    self.registrar = registrar
    dataSource = CollectionViewDiffableDataSource(collectionView: collectionView) { cv, indexPath, item in
      item._dequeue(cv, indexPath, registrar)
    }
  }

  // MARK: Public

  /// A convenience alias for the snapshot type used by this data source.
  public typealias Snapshot = DiffableDataSourceSnapshot<SectionID, AnyItem>

  /// An optional closure for providing supplementary views (headers, footers).
  public var supplementaryViewProvider: CollectionViewDiffableDataSource<SectionID, AnyItem>.SupplementaryViewProvider? {
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

  /// Returns the header text for the given section, or `nil` if none was set.
  public func headerForSection(_ sectionID: SectionID) -> String? {
    sectionHeaders[sectionID]
  }

  /// Returns the footer text for the given section, or `nil` if none was set.
  public func footerForSection(_ sectionID: SectionID) -> String? {
    sectionFooters[sectionID]
  }

  /// Applies the given snapshot, computing and animating the minimal diff.
  ///
  /// Items whose wrapped type conforms to ``ContentEquatable`` are automatically
  /// checked for content changes and marked for reconfiguration.
  public func apply(_ snapshot: Snapshot, animatingDifferences: Bool = true) async {
    var snapshot = snapshot
    autoReconfigure(old: dataSource.snapshot(), new: &snapshot)
    await dataSource.apply(snapshot, animatingDifferences: animatingDifferences)
  }

  /// Replaces the current data without diffing, calling `reloadData()` on the collection view.
  public func applyUsingReloadData(_ snapshot: Snapshot) async {
    await dataSource.applySnapshotUsingReloadData(snapshot)
  }

  /// Applies sections built with the ``MixedSnapshotBuilder`` result builder DSL.
  ///
  /// Header and footer text from each ``MixedSection`` is stored and accessible via
  /// ``headerForSection(_:)`` and ``footerForSection(_:)``. Call
  /// ``configureListHeaderFooterProvider()`` to automatically wire these into
  /// supplementary views when using a list layout with `.supplementary` header/footer modes.
  ///
  /// Cancels any previously queued apply so only the most recent snapshot is applied,
  /// and supports cooperative cancellation from the calling task.
  public func apply(
    animatingDifferences: Bool = true,
    @MixedSnapshotBuilder<SectionID> content: () -> [MixedSection<SectionID>]
  ) async {
    let sections = content()
    applyTask?.cancel()
    let previousTask = applyTask
    let task = Task { [weak self] in
      _ = await previousTask?.value
      guard !Task.isCancelled, let self else { return }
      var snapshot = Snapshot()
      var newHeaders = [SectionID: String]()
      var newFooters = [SectionID: String]()
      for section in sections {
        snapshot.appendSections([section.id])
        snapshot.appendItems(section.items, toSection: section.id)
        if let header = section.header {
          newHeaders[section.id] = header
        }
        if let footer = section.footer {
          newFooters[section.id] = footer
        }
      }
      // Merge so both old and new sections have valid headers during animation
      sectionHeaders.merge(newHeaders) { _, new in new }
      sectionFooters.merge(newFooters) { _, new in new }
      await apply(snapshot, animatingDifferences: animatingDifferences)
      // Trim to only current sections after apply completes
      sectionHeaders = newHeaders
      sectionFooters = newFooters
    }
    applyTask = task
    await withTaskCancellationHandler {
      await task.value
    } onCancel: {
      task.cancel()
    }
  }

  /// Applies a hierarchical section snapshot to a specific section for outline-style content.
  public func apply(
    _ sectionSnapshot: DiffableDataSourceSectionSnapshot<AnyItem>,
    to section: SectionID,
    animatingDifferences: Bool = true
  ) async {
    await dataSource.apply(sectionSnapshot, to: section, animatingDifferences: animatingDifferences)
  }

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

  /// Configures ``supplementaryViewProvider`` to render header and footer text
  /// using `UICollectionViewListCell` with grouped header/footer content configurations.
  ///
  /// Call this after initialization when your layout uses
  /// `headerMode: .supplementary` and/or `footerMode: .supplementary`.
  /// Header and footer text is sourced from ``headerForSection(_:)`` and
  /// ``footerForSection(_:)``, populated by ``apply(content:)``.
  public func configureListHeaderFooterProvider() {
    let headerRegistration = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(
      elementKind: UICollectionView.elementKindSectionHeader
    ) { [weak self] supplementaryView, _, indexPath in
      guard let self else { return }
      guard let sectionID = dataSource.sectionIdentifier(for: indexPath.section) else {
        assertionFailure("Section index \(indexPath.section) out of bounds")
        return
      }
      var content = UIListContentConfiguration.groupedHeader()
      content.text = sectionHeaders[sectionID]
      supplementaryView.contentConfiguration = content
    }

    let footerRegistration = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(
      elementKind: UICollectionView.elementKindSectionFooter
    ) { [weak self] supplementaryView, _, indexPath in
      guard let self else { return }
      guard let sectionID = dataSource.sectionIdentifier(for: indexPath.section) else {
        assertionFailure("Section index \(indexPath.section) out of bounds")
        return
      }
      var content = UIListContentConfiguration.groupedFooter()
      content.text = sectionFooters[sectionID]
      supplementaryView.contentConfiguration = content
    }

    supplementaryViewProvider = { collectionView, kind, indexPath in
      switch kind {
      case UICollectionView.elementKindSectionHeader:
        return collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
      case UICollectionView.elementKindSectionFooter:
        return collectionView.dequeueConfiguredReusableSupplementary(using: footerRegistration, for: indexPath)
      default:
        assertionFailure("Unexpected supplementary view kind: \(kind)")
        return nil
      }
    }
  }

  // MARK: Private

  private let registrar: DynamicCellRegistrar
  private let dataSource: CollectionViewDiffableDataSource<SectionID, AnyItem>
  private var sectionHeaders = [SectionID: String]()
  private var sectionFooters = [SectionID: String]()
  private var applyTask: Task<Void, Never>?

  /// Detects content changes for ``AnyItem`` values whose wrapped types conform to
  /// ``ContentEquatable`` and marks them for reconfiguration.
  private func autoReconfigure(old: Snapshot, new: inout Snapshot) {
    let oldItems = old.itemIdentifiers
    guard !oldItems.isEmpty else { return }

    var oldLookup = [AnyItem: AnyItem]()
    oldLookup.reserveCapacity(oldItems.count)
    for item in oldItems {
      oldLookup[item] = item
    }

    var toReconfigure = [AnyItem]()
    for newItem in new.itemIdentifiers {
      guard let oldItem = oldLookup[newItem] else { continue }
      if !newItem.isContentEqual(to: oldItem) {
        toReconfigure.append(newItem)
      }
    }

    if !toReconfigure.isEmpty {
      new.reconfigureItems(toReconfigure)
    }
  }

}
