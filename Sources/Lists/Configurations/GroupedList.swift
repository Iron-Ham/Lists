import ListKit
import UIKit

/// A multi-section list with headers and footers, backed by a `UICollectionView`.
///
/// `GroupedList` manages an inset-grouped layout with supplementary header/footer views
/// automatically. Provide ``SectionModel`` values to populate sections.
///
/// ```swift
/// let list = GroupedList<String, ContactItem>()
/// await list.setSections([
///     SectionModel(id: "friends", items: friends, header: "Friends"),
/// ])
/// ```
@MainActor
public final class GroupedList<SectionID: Hashable & Sendable, Item: CellViewModel>: NSObject, UICollectionViewDelegate {

  // MARK: Lifecycle

  /// Creates a grouped list with the specified list appearance.
  public init(appearance: UICollectionLayoutListConfiguration.Appearance = .insetGrouped) {
    let bridge = SwipeActionBridge<SectionID, Item>()
    self.bridge = bridge

    var config = UICollectionLayoutListConfiguration(appearance: appearance)
    config.headerMode = .supplementary
    config.footerMode = .supplementary
    bridge.configureSwipeActions(on: &config)
    let layout = UICollectionViewCompositionalLayout.list(using: config)

    collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
    dataSource = ListDataSource(collectionView: collectionView)
    super.init()
    collectionView.delegate = self
    setupSupplementaryViews()

    bridge.dataSource = dataSource
    bridge.trailingProvider = { [weak self] item in self?.trailingSwipeActionsProvider?(item) }
    bridge.leadingProvider = { [weak self] item in self?.leadingSwipeActionsProvider?(item) }
  }

  // MARK: Public

  /// The underlying collection view. Add this to your view hierarchy.
  public let collectionView: UICollectionView
  /// Called when the user taps an item.
  public var onSelect: (@MainActor (Item) -> Void)?

  /// Closure that returns trailing swipe actions for a given item.
  public var trailingSwipeActionsProvider: (@MainActor (Item) -> UISwipeActionsConfiguration?)?
  /// Closure that returns leading swipe actions for a given item.
  public var leadingSwipeActionsProvider: (@MainActor (Item) -> UISwipeActionsConfiguration?)?
  /// Closure that returns a context menu configuration for a given item.
  public var contextMenuProvider: (@MainActor (Item) -> UIContextMenuConfiguration?)?

  /// Replaces all sections, computing and animating the diff.
  ///
  /// Cancels any previously queued apply so only the most recent snapshot is applied,
  /// and supports cooperative cancellation from the calling task.
  public func setSections(_ sections: [SectionModel<SectionID, Item>], animatingDifferences: Bool = true) async {
    applyTask?.cancel()
    let previousTask = applyTask
    let task = Task { [weak self] in
      _ = await previousTask?.value
      guard !Task.isCancelled, let self else { return }
      var newHeaders = [SectionID: String]()
      var newFooters = [SectionID: String]()
      for section in sections {
        if let header = section.header {
          newHeaders[section.id] = header
        }
        if let footer = section.footer {
          newFooters[section.id] = footer
        }
      }
      // Merge new values so both old and new sections have valid headers during animation
      sectionHeaders.merge(newHeaders) { _, new in new }
      sectionFooters.merge(newFooters) { _, new in new }
      await dataSource.apply(sections, animatingDifferences: animatingDifferences)
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

  /// Returns a copy of the current snapshot.
  public func snapshot() -> DiffableDataSourceSnapshot<SectionID, Item> {
    dataSource.snapshot()
  }

  public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    collectionView.deselectItem(at: indexPath, animated: true)
    guard let item = dataSource.itemIdentifier(for: indexPath) else {
      assertionFailure("Item not found for indexPath \(indexPath)")
      return
    }
    onSelect?(item)
  }

  public func collectionView(
    _: UICollectionView,
    contextMenuConfigurationForItemAt indexPath: IndexPath,
    point _: CGPoint
  ) -> UIContextMenuConfiguration? {
    guard let item = dataSource.itemIdentifier(for: indexPath) else { return nil }
    return contextMenuProvider?(item)
  }

  // MARK: Private

  private let dataSource: ListDataSource<SectionID, Item>
  private let bridge: SwipeActionBridge<SectionID, Item>
  private var sectionHeaders = [SectionID: String]()
  private var sectionFooters = [SectionID: String]()
  private var applyTask: Task<Void, Never>?

  private func setupSupplementaryViews() {
    let headerRegistration = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(
      elementKind: UICollectionView.elementKindSectionHeader
    ) { [weak self] supplementaryView, _, indexPath in
      guard let self else { return }
      let snapshot = dataSource.snapshot()
      let sectionIdentifiers = snapshot.sectionIdentifiers
      guard indexPath.section < sectionIdentifiers.count else { return }
      let sectionID = sectionIdentifiers[indexPath.section]
      var content = UIListContentConfiguration.groupedHeader()
      content.text = sectionHeaders[sectionID]
      supplementaryView.contentConfiguration = content
    }

    let footerRegistration = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(
      elementKind: UICollectionView.elementKindSectionFooter
    ) { [weak self] supplementaryView, _, indexPath in
      guard let self else { return }
      let snapshot = dataSource.snapshot()
      let sectionIdentifiers = snapshot.sectionIdentifiers
      guard indexPath.section < sectionIdentifiers.count else { return }
      let sectionID = sectionIdentifiers[indexPath.section]
      var content = UIListContentConfiguration.groupedFooter()
      content.text = sectionFooters[sectionID]
      supplementaryView.contentConfiguration = content
    }

    dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
      switch kind {
      case UICollectionView.elementKindSectionHeader:
        collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
      case UICollectionView.elementKindSectionFooter:
        collectionView.dequeueConfiguredReusableSupplementary(using: footerRegistration, for: indexPath)
      default:
        nil
      }
    }
  }
}
