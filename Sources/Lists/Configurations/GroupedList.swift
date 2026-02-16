import ListKit
import UIKit

/// A multi-section list with headers and footers, backed by a `UICollectionView`.
///
/// `GroupedList` manages an inset-grouped layout with supplementary header/footer views
/// automatically. Provide ``SectionModel`` values to populate sections.
///
/// ## Layout Configuration
///
/// Layout properties (`appearance`, `showsSeparators`, `headerMode`, `footerMode`,
/// `separatorColor`, `backgroundColor`, `headerTopPadding`) are set during initialization
/// and cannot be changed afterward. This is a UIKit limitation —
/// `UICollectionLayoutListConfiguration` is snapshot-immutable once the layout is created.
/// Dynamic properties like ``allowsMultipleSelection`` and ``isEditing`` can be changed
/// at any time.
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

  deinit {
    applyTask?.cancel()
  }

  /// Creates a grouped list with the specified list appearance.
  ///
  /// - Parameters:
  ///   - appearance: The visual style of the list (e.g., `.insetGrouped`, `.plain`, `.sidebar`).
  ///   - showsSeparators: Whether separators are shown between rows.
  ///   - headerMode: How section headers are displayed. Defaults to `.supplementary`.
  ///   - footerMode: How section footers are displayed. Defaults to `.supplementary`.
  ///   - separatorColor: A global tint color applied to all item separators. Per-item
  ///     customization via ``separatorHandler`` takes precedence.
  ///   - backgroundColor: An optional background color for the list. When `nil`, the system default is used.
  ///   - headerTopPadding: Extra padding above each section header. When `nil`, the system default is used.
  public init(
    appearance: UICollectionLayoutListConfiguration.Appearance = .insetGrouped,
    showsSeparators: Bool = true,
    headerMode: UICollectionLayoutListConfiguration.HeaderMode = .supplementary,
    footerMode: UICollectionLayoutListConfiguration.FooterMode = .supplementary,
    separatorColor: UIColor? = nil,
    backgroundColor: UIColor? = nil,
    headerTopPadding: CGFloat? = nil
  ) {
    let bridge = ListConfigurationBridge<SectionID, Item>()
    self.bridge = bridge
    bridge.setDefaultSeparatorColor(separatorColor)

    var config = UICollectionLayoutListConfiguration(appearance: appearance)
    config.headerMode = headerMode
    config.footerMode = footerMode
    config.showsSeparators = showsSeparators
    if let backgroundColor {
      config.backgroundColor = backgroundColor
    }
    if let headerTopPadding {
      config.headerTopPadding = headerTopPadding
    }
    bridge.configure(&config)
    let layout = UICollectionViewCompositionalLayout.list(using: config)

    collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
    dataSource = ListDataSource(collectionView: collectionView)
    super.init()
    collectionView.delegate = self
    // Register supplementary views only when at least one mode is .supplementary.
    // Both header and footer registrations are created together; the layout only
    // requests the kinds matching its configuration, so unused registrations are inert.
    if headerMode == .supplementary || footerMode == .supplementary {
      setupSupplementaryViews()
    }

    bridge.setDataSource(dataSource)
    // trailingSwipeActionsProvider takes precedence; onDelete is the fallback.
    bridge.setTrailingProvider { [weak self] item in
      guard let self else { return nil }
      if let config = trailingSwipeActionsProvider?(item) {
        return config
      }
      guard let onDelete else { return nil }
      let action = UIContextualAction(style: .destructive, title: String(localized: "Delete")) { _, _, completion in
        onDelete(item)
        completion(true)
      }
      return UISwipeActionsConfiguration(actions: [action])
    }
    bridge.setLeadingProvider { [weak self] item in self?.leadingSwipeActionsProvider?(item) }
  }

  // MARK: Public

  /// The underlying collection view. Add this to your view hierarchy.
  public let collectionView: UICollectionView
  /// Called when the user taps an item.
  public var onSelect: (@MainActor (Item) -> Void)?
  /// Called when the user deselects an item (relevant when `allowsMultipleSelection` is enabled).
  public var onDeselect: (@MainActor (Item) -> Void)?

  /// Called when the user swipe-deletes an item. When set and ``trailingSwipeActionsProvider``
  /// is `nil`, a trailing destructive "Delete" swipe action is provided automatically.
  ///
  /// - Important: The caller is responsible for removing the item from the data source
  ///   after this callback fires. The list does not automatically mutate its snapshot.
  ///
  /// - Note: The swipe action always completes as "performed" regardless of whether the
  ///   underlying operation succeeds. Ensure your handler updates the data source to
  ///   reflect the actual result.
  public var onDelete: (@MainActor (Item) -> Void)?

  /// Closure that returns trailing swipe actions for a given item.
  public var trailingSwipeActionsProvider: (@MainActor (Item) -> UISwipeActionsConfiguration?)?
  /// Closure that returns leading swipe actions for a given item.
  public var leadingSwipeActionsProvider: (@MainActor (Item) -> UISwipeActionsConfiguration?)?
  /// Closure that returns a context menu configuration for a given item.
  public var contextMenuProvider: (@MainActor (Item) -> UIContextMenuConfiguration?)?

  /// Closure that returns a custom content configuration for a section header.
  ///
  /// When set, this takes precedence over the text-based header from ``SectionModel``.
  /// Return `nil` to fall back to the text header for a specific section.
  ///
  /// ```swift
  /// list.headerContentProvider = { sectionID in
  ///     var config = UIListContentConfiguration.prominentInsetGroupedHeader()
  ///     config.text = sectionID
  ///     config.image = UIImage(systemName: "star")
  ///     return config
  /// }
  /// ```
  public var headerContentProvider: (@MainActor (SectionID) -> UIContentConfiguration?)?

  /// Closure that returns a custom content configuration for a section footer.
  ///
  /// When set, this takes precedence over the text-based footer from ``SectionModel``.
  /// Return `nil` to fall back to the text footer for a specific section.
  public var footerContentProvider: (@MainActor (SectionID) -> UIContentConfiguration?)?

  /// Per-item separator customization handler.
  ///
  /// Called for each item before display. Return a modified configuration to customize
  /// separator appearance (color, insets, visibility) on a per-item basis.
  ///
  /// ```swift
  /// list.separatorHandler = { item, defaultConfig in
  ///     var config = defaultConfig
  ///     config.color = .systemRed
  ///     config.bottomSeparatorInsets.leading = 16
  ///     return config
  /// }
  /// ```
  public var separatorHandler: (@MainActor (Item, UIListSeparatorConfiguration) -> UIListSeparatorConfiguration)? {
    didSet { bridge.setSeparatorProvider(separatorHandler) }
  }

  /// Whether the list allows multiple simultaneous selections.
  ///
  /// When `true`, tapping an item does not automatically deselect other items.
  /// Use ``onDeselect`` to track deselection events.
  public var allowsMultipleSelection: Bool {
    get { collectionView.allowsMultipleSelection }
    set { collectionView.allowsMultipleSelection = newValue }
  }

  /// Whether selection is allowed during editing mode.
  public var allowsSelectionDuringEditing: Bool {
    get { collectionView.allowsSelectionDuringEditing }
    set { collectionView.allowsSelectionDuringEditing = newValue }
  }

  /// Whether multiple selection is allowed during editing mode.
  public var allowsMultipleSelectionDuringEditing: Bool {
    get { collectionView.allowsMultipleSelectionDuringEditing }
    set { collectionView.allowsMultipleSelectionDuringEditing = newValue }
  }

  /// Whether the list is in editing mode.
  ///
  /// When `true`, cells may display editing controls such as delete and reorder accessories.
  public var isEditing: Bool {
    get { collectionView.isEditing }
    set { collectionView.isEditing = newValue }
  }

  /// Called when the user reorders an item via drag-and-drop.
  /// The list updates its internal snapshot automatically; use this to persist the new order.
  /// Setting this enables the reorder interaction on the collection view.
  public var onMove: (@MainActor (_ source: IndexPath, _ destination: IndexPath) -> Void)? {
    didSet { configureReorderIfNeeded() }
  }

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

  /// Replaces all sections using the ``SnapshotBuilder`` result builder DSL.
  ///
  /// - Note: ``SnapshotSection`` carries only an identifier and items — it does not support
  ///   header or footer text. To display section headers and footers, either use the
  ///   array-based ``setSections(_:animatingDifferences:)`` with ``SectionModel`` values
  ///   that include `header`/`footer`, or set ``headerContentProvider`` /
  ///   ``footerContentProvider`` for fully custom supplementary content.
  ///
  /// ```swift
  /// await list.setSections {
  ///     SnapshotSection("favorites") {
  ///         favoriteItem1
  ///         favoriteItem2
  ///     }
  ///     SnapshotSection("recent") {
  ///         recentItem1
  ///     }
  /// }
  /// ```
  public func setSections(
    animatingDifferences: Bool = true,
    @SnapshotBuilder<SectionID, Item> content: () -> [SnapshotSection<SectionID, Item>]
  ) async {
    let sections = content().map { section in
      SectionModel(id: section.id, items: section.items)
    }
    await setSections(sections, animatingDifferences: animatingDifferences)
  }

  /// Returns a copy of the current snapshot.
  public func snapshot() -> DiffableDataSourceSnapshot<SectionID, Item> {
    dataSource.snapshot()
  }

  /// Returns the item at the given index path, or `nil` if out of bounds.
  public func itemIdentifier(for indexPath: IndexPath) -> Item? {
    bridge.itemIdentifier(for: indexPath)
  }

  /// Returns the index path for the specified item, or `nil` if not found.
  public func indexPath(for item: Item) -> IndexPath? {
    bridge.indexPath(for: item)
  }

  /// Programmatically scrolls to the specified item.
  ///
  /// - Returns: `true` if the item was found in the current snapshot and the scroll was
  ///   initiated, `false` if the item is not present. For items removed between snapshot
  ///   updates, this returns `false` without side effects.
  @discardableResult
  public func scrollToItem(
    _ item: Item,
    at scrollPosition: UICollectionView.ScrollPosition = .centeredVertically,
    animated: Bool = true
  ) -> Bool {
    bridge.scrollToItem(item, in: collectionView, at: scrollPosition, animated: animated)
  }

  public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    bridge.handleDidSelect(in: collectionView, at: indexPath, onSelect: onSelect)
  }

  public func collectionView(_: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
    bridge.handleDidDeselect(at: indexPath, onDeselect: onDeselect)
  }

  public func collectionView(
    _: UICollectionView,
    contextMenuConfigurationForItemAt indexPath: IndexPath,
    point _: CGPoint
  ) -> UIContextMenuConfiguration? {
    bridge.handleContextMenu(at: indexPath, provider: contextMenuProvider)
  }

  // MARK: Private

  private let dataSource: ListDataSource<SectionID, Item>
  private let bridge: ListConfigurationBridge<SectionID, Item>
  private var sectionHeaders = [SectionID: String]()
  private var sectionFooters = [SectionID: String]()
  private var applyTask: Task<Void, Never>?

  private func configureReorderIfNeeded() {
    if onMove != nil {
      collectionView.dragInteractionEnabled = true
      dataSource.canMoveItemHandler = { _ in true }
      dataSource.didMoveItemHandler = { [weak self] source, dest in
        self?.onMove?(source, dest)
      }
    } else {
      collectionView.dragInteractionEnabled = false
      dataSource.canMoveItemHandler = nil
      dataSource.didMoveItemHandler = nil
    }
  }

  private func setupSupplementaryViews() {
    let headerRegistration = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(
      elementKind: UICollectionView.elementKindSectionHeader
    ) { [weak self] supplementaryView, _, indexPath in
      guard let self else { return }
      guard let sectionID = dataSource.sectionIdentifier(for: indexPath.section) else {
        assertionFailure("Section index \(indexPath.section) out of bounds")
        return
      }
      if let contentConfig = headerContentProvider?(sectionID) {
        supplementaryView.contentConfiguration = contentConfig
      } else {
        var content = UIListContentConfiguration.groupedHeader()
        content.text = sectionHeaders[sectionID]
        supplementaryView.contentConfiguration = content
      }
    }

    let footerRegistration = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(
      elementKind: UICollectionView.elementKindSectionFooter
    ) { [weak self] supplementaryView, _, indexPath in
      guard let self else { return }
      guard let sectionID = dataSource.sectionIdentifier(for: indexPath.section) else {
        assertionFailure("Section index \(indexPath.section) out of bounds")
        return
      }
      if let contentConfig = footerContentProvider?(sectionID) {
        supplementaryView.contentConfiguration = contentConfig
      } else {
        var content = UIListContentConfiguration.groupedFooter()
        content.text = sectionFooters[sectionID]
        supplementaryView.contentConfiguration = content
      }
    }

    dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
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
}
